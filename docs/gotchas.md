# IIS and platform gotchas (Windows Elastic Beanstalk + .NET Framework 4.8)

Client handover (verification, module, acceptance): `docs/handover-dotnet48-elastic-beanstalk.md`.  
Engineering validation (plan, substitution, failures): `docs/engineering-validation.md`.

This file is the engineering log behind that handover.

## Success check (sandbox only, no Matchbook resources)

| Check | Result |
| --- | --- |
| Windows EB environment | `mb-dotnet48-sandbox`, `Ready` / Green |
| Application | `matchbook-dotnet48-sample` |
| Platform version | `64bit Windows Server 2022 v2.23.4 running IIS 10.0` |
| Instance type | `t3.micro` |
| URL | http://mb-dotnet48-sandbox.eba-ypp8zvmp.us-east-1.elasticbeanstalk.com/ |
| App loads | `GET /` → 200 |
| Runs .NET Framework 4.8 | `GET /Default.aspx` → CLR `4.0.30319.42000`, `.NET Framework 4.8.9339.0`, `HttpRuntime.TargetFramework = 4.8` |
| OpenTofu version | `app-b07b905331f6` |

Account `178231953614`, region `us-east-1`.

## OpenTofu module

Path: `tofu/modules/beanstalk_environment`, used by `tofu/environments/sandbox`.

```
OpenTofu
  → Elastic Beanstalk Application
  → Elastic Beanstalk Environment
  → Windows IIS instance
  → sample .NET 4.8 zip (or Matchbook zip)
  → working URL
```

Required inputs:

| Manager parameter | Variable | Sandbox value |
| --- | --- | --- |
| application name | `application_name` | `matchbook-dotnet48-sample` |
| environment | `environment` | `mb-dotnet48-sandbox` |
| instance type | `instance_type` | `t3.micro` |
| platform version | `platform_version` | `64bit Windows Server 2022 v2.23.4 running IIS 10.0` |

Apply from `tofu/environments/sandbox` with `/home/dev/Desktop/matchbook/bin/tofu`.

## Platform version

- Windows Server **2019** ships **.NET Framework 4.8**.
- Windows Server **2022/2025** ships **.NET Framework 4.8.1**, which runs 4.8 apps. This sandbox uses 2022 / IIS 10.0.
- Windows Server **2016** retires **2026-09-30**. Do not use it.
- Pin `platform_version` to a full solution stack name so patch bumps (v2.23.4 → v2.23.5) are not applied in place.

## IIS configuration that was required

Windows Beanstalk does **not** copy a raw `.aspx` zip into IIS unless the bundle includes `aws-windows-deployment-manifest.json`.

Required pieces in `sample-app/`:

- `web.config` — `compilation` / `httpRuntime` `targetFramework="4.8"`, default documents `Default.htm` then `Default.aspx`
- `Default.htm` — makes `GET /` return 200 (IIS 403.14 otherwise)
- `Default.aspx` — reports CLR / Framework / TargetFramework
- `aws-windows-deployment-manifest.json` — `"architecture": 64` (default is 32-bit PowerShell; IIS `WebAdministration` fails with `REGDB_E_CLASSNOTREG`)
- `install.ps1` — copy site files into `C:\inetpub\wwwroot`, including directories (`bin/`, `Views/`)
- `restart.ps1` — start `WAS`/`W3SVC` and exit 0 (`iisreset` / `appcmd recycle` can stop IIS and fail the deploy)

`403.14` on `/` with `/iisstart.htm` = 200 means IIS is up and the sample is not in `wwwroot`.

## Other gotchas

- This sandbox account rejects `t3.medium` (“not eligible for Free Tier”). Use `t3.micro` here.
- Windows boot is 10–20+ minutes. `wait_for_ready_timeout = 45m`. Default VPC must exist.
- Two IAM roles: instance profile (`AWSElasticBeanstalkWebTier` + `AmazonSSMManagedInstanceCore`) and service role (`AWSElasticBeanstalkEnhancedHealth` + `AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy`). Versions bucket name must start with `elasticbeanstalk-`.
- `SingleInstance` (EIP, no ALB) is the sandbox default. `environment_type = "LoadBalanced"` is a variable, not a rebuild.

## Matchbook substitution (no rebuild)

Swapping the sample for the Matchbook artifact is an input change. Keep `application_name`, `environment`, `instance_type`, and `platform_version`.

| `artifact_format` | What Kuldip sent | What you set |
| --- | --- | --- |
| `sample` | nothing (current) | default; zips `sample-app/` |
| `publish_zip` | zipped publish output (`web.config`, `bin/`, site files) | `source_bundle_path` + optional `web_config_path`; OpenTofu wraps the proven custom IIS deploy around it |
| `webdeploy` | Azure DevOps Web Deploy package (`.deploy.cmd`, `parameters.xml`) | `source_bundle_path` only; Beanstalk runs msdeploy |

Drop files in `artifacts/incoming/` (see `artifacts/README.md`). Then in `tofu/environments/sandbox/terraform.tfvars`:

```hcl
artifact_format    = "publish_zip"
source_bundle_path = "../../../artifacts/incoming/private-api-publish.zip"
web_config_path    = "../../../artifacts/incoming/web.config"
```

or:

```hcl
artifact_format    = "webdeploy"
source_bundle_path = "../../../artifacts/incoming/private-api.webdeploy.zip"
```

Config injection without rebuilding IIS:

```hcl
health_check_path = "/health"
app_environment_variables = {
  RedisHost = "example.cache.amazonaws.com"
}
```

`scripts/prepare_beanstalk_bundle.py` is what wraps `publish_zip`. You do not run it by hand; `tofu apply` does.

### Request from Kuldip (Private API first)

Ask for the artifact their Azure DevOps release pipeline already produces, for **one** application — the Private API.

- Vijay: APIs use Redis for **token metadata**, not sessions, so this avoids the Client Portal's hard Redis dependency.
- Format: Web Deploy package **or** zipped publish output.
- Send `web.config` alongside it (untransformed if possible) so IIS modules and COM references are visible before deploy.

### Expected outcome when Redis is missing

Vijay: Redis is mandatory for **session activation**. A deployment with no backing services may only reach a health check. Treat that as expected, not as a Beanstalk/IIS failure. Capture the status code and body; then wire Redis through `app_environment_variables` rather than recreating the environment.

### Findings to capture after the first Matchbook deploy

Fill this in when the artifact is received (do not treat blank rows as current failures):

| Area | What to look at | Result |
| --- | --- | --- |
| Bundle format | publish zip vs Web Deploy; did wrap/msdeploy succeed? | |
| IIS modules | `system.webServer/modules`, `httpModules`, URL Rewrite, WebSockets | |
| Handlers | `system.webServer/handlers`, `*.svc` / `*.ashx` | |
| COM / native | `web.config` COM refs, `.dll` besides managed `bin/` | |
| Session / Redis | `sessionState`, custom providers, token cache | |
| Config injection | connectionStrings / appSettings names; what EB env vars mapped | |
| Health | path that returns 200 without Redis; app paths that do not | |
| Identity / HTTPS | Windows auth, TLS offload, ARR | |

A raw publish zip **without** wrapping still hits `01deploy.ps1` exit `-1` on this platform. That is why `publish_zip` exists.
