#!/usr/bin/env python3
"""Build a Windows Elastic Beanstalk zip from a Matchbook publish output.

Elastic Beanstalk on Windows does not reliably copy a raw ASP.NET publish zip
into IIS. This script wraps the proven custom deploy (manifest + install.ps1)
around the application files so swapping Matchbook in is:

    incoming zip  ->  this script  ->  source_bundle_path  ->  tofu apply

Web Deploy packages are left unchanged; the platform runs msdeploy itself.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

DEPLOY_FILES = (
    "aws-windows-deployment-manifest.json",
    "install.ps1",
    "restart.ps1",
    "uninstall.ps1",
)
FIXED_ZIP_TIME = (2020, 1, 1, 0, 0, 0)


def _is_webdeploy(root: Path) -> bool:
    names = {p.name.lower() for p in root.rglob("*") if p.is_file()}
    if any(n.endswith(".deploy.cmd") for n in names):
        return True
    if "parameters.xml" in names and any(n.endswith(".sourceManifest.xml".lower()) for n in names):
        return True
    return False


def _copy_deterministic(zf: zipfile.ZipFile, src: Path, arcname: str) -> None:
    info = zipfile.ZipInfo(arcname.replace("\\", "/"))
    info.date_time = FIXED_ZIP_TIME
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    zf.writestr(info, src.read_bytes())


def _zip_dir(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        dest.unlink()
    with zipfile.ZipFile(dest, "w") as zf:
        for path in sorted(src.rglob("*")):
            if not path.is_file():
                continue
            _copy_deterministic(zf, path, str(path.relative_to(src)))


def _extract(zip_path: Path, dest: Path) -> None:
    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(dest)


def _site_source(extracted: Path) -> Path:
    children = [p for p in extracted.iterdir() if p.name not in {".", "..", "__MACOSX"}]
    if len(children) == 1 and children[0].is_dir() and not (children[0] / "web.config").exists():
        nested = list(children[0].iterdir())
        if any(p.name.lower() == "web.config" for p in nested):
            return children[0]
    return extracted


def wrap_publish(input_zip: Path, sample_app: Path, output_zip: Path, web_config: Path | None) -> Path:
    with tempfile.TemporaryDirectory(prefix="eb-wrap-") as tmp:
        tmp_path = Path(tmp)
        extracted = tmp_path / "extracted"
        staging = tmp_path / "staging"
        site = staging / "site"
        extracted.mkdir()
        staging.mkdir()
        site.mkdir()
        _extract(input_zip, extracted)
        if _is_webdeploy(extracted):
            raise SystemExit(
                "Input looks like a Web Deploy package (.deploy.cmd / parameters.xml). "
                "Set artifact_format = \"webdeploy\" and point source_bundle_path at it; "
                "do not wrap it as publish_zip."
            )
        src = _site_source(extracted)
        for item in src.iterdir():
            if item.name in DEPLOY_FILES or item.name == "__MACOSX":
                continue
            dest = site / item.name
            if item.is_dir():
                shutil.copytree(item, dest, dirs_exist_ok=True)
            else:
                shutil.copy2(item, dest)
        if web_config:
            shutil.copy2(web_config, site / "web.config")
        for name in DEPLOY_FILES:
            shutil.copy2(sample_app / name, staging / name)
        _zip_dir(staging, output_zip)
    return output_zip


def copy_as_is(input_zip: Path, output_zip: Path) -> Path:
    output_zip.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(input_zip, output_zip)
    return output_zip


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run(args: argparse.Namespace) -> dict[str, str]:
    output = Path(args.output).resolve()
    sample_app = Path(args.sample_app).resolve()
    web_config = Path(args.web_config).resolve() if args.web_config else None

    if args.format == "sample":
        if not sample_app.is_dir():
            raise SystemExit(f"sample-app directory not found: {sample_app}")
        _zip_dir(sample_app, output)
        return {"path": str(output), "md5": _sha256(output)[:32], "format": "sample"}

    input_zip = Path(args.input).resolve()
    if not input_zip.is_file():
        raise SystemExit(f"artifact zip not found: {input_zip}")

    if args.format == "webdeploy":
        copy_as_is(input_zip, output)
        return {"path": str(output), "md5": _sha256(output)[:32], "format": "webdeploy"}

    if args.format == "publish_zip":
        wrap_publish(input_zip, sample_app, output, web_config)
        return {"path": str(output), "md5": _sha256(output)[:32], "format": "publish_zip"}

    raise SystemExit(f"unknown format: {args.format}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--format",
        required=True,
        choices=("sample", "publish_zip", "webdeploy"),
    )
    parser.add_argument("--input", default="", help="Matchbook zip (publish output or Web Deploy package)")
    parser.add_argument("--sample-app", required=True, help="Path to sample-app (deploy scripts + sample site)")
    parser.add_argument("--output", required=True, help="Beanstalk-ready zip to write")
    parser.add_argument("--web-config", default="", help="Optional sidecar web.config to overlay into site/")
    parser.add_argument("--json", action="store_true", help="Print path/md5 JSON (OpenTofu external data)")
    return parser.parse_args(argv)


def main() -> None:
    if len(sys.argv) == 1 or (len(sys.argv) == 2 and sys.argv[1] == "--json"):
        query = json.load(sys.stdin)
        args = argparse.Namespace(
            format=query["format"],
            input=query.get("input") or "",
            sample_app=query["sample_app"],
            output=query["output"],
            web_config=query.get("web_config") or "",
            json=True,
        )
        result = run(args)
        json.dump(result, sys.stdout)
        return

    args = parse_args(sys.argv[1:])
    result = run(args)
    if args.json:
        json.dump(result, sys.stdout)
        sys.stdout.write("\n")
        return
    sys.stdout.write(f"{result['path']}\n")


if __name__ == "__main__":
    main()
