# .NET Framework 4.8 on Windows Elastic Beanstalk

**Client handover**  
Sandbox proof of platform + reusable OpenTofu module

| | |
| --- | --- |
| Date | 16 September 2026 |
| Account | AWS sandbox `178231953614` |
| Region | `us-east-1` |
| Scope | Sandbox only. No Matchbook application, artifact, or account was used. |
| Status | **Complete** |

This document is the handover for two agreed deliverables. It is written so a reader can confirm the result in a browser, then reproduce the same environment from code.

---

## What was asked for

### 1. .NET 4.8 application on Elastic Beanstalk

Deploy a sample .NET Framework 4.8 application to a Windows Elastic Beanstalk environment in the sandbox, to prove the platform supports the runtime. Deliver a working environment and document IIS configuration and platform-version findings. Use only the sandbox account.

### 2. OpenTofu module for the Beanstalk environment

Wrap that working setup in reusable infrastructure as code. Parameterise on application name, environment, instance type, and platform version, so a later Matchbook artifact is a substitution, not a rebuild.

---

## How to verify in two minutes

1. Open this URL in a browser:

   **http://mb-dotnet48-sandbox.eba-ypp8zvmp.us-east-1.elasticbeanstalk.com/**

2. The home page loads (HTTP 200). Follow the link to **Default.aspx**.

3. The page reports the runtime on the live IIS server:

   | Check | Value on the live environment |
   | --- | --- |
   | CLR | `4.0.30319.42000` |
   | Framework | `.NET Framework 4.8.9339.0` |
   | Application target | `4.8` |
   | Web server | IIS 10.0 (`X-Powered-By: ASP.NET`) |

That is the proof that Windows Elastic Beanstalk in this sandbox runs .NET Framework 4.8.

---

## Deliverable 1 — Working environment

A Windows Elastic Beanstalk environment is running in the sandbox and serving the sample application.

| Item | Value |
| --- | --- |
| Elastic Beanstalk application | `matchbook-dotnet48-sample` |
| Environment name | `mb-dotnet48-sandbox` |
| Environment ID | `e-kbthhytguj` |
| Status / health | Ready / Green |
| Platform (pinned) | `64bit Windows Server 2022 v2.23.4 running IIS 10.0` |
| Instance type | `t3.micro` (required on this Free Tier-restricted account) |
| Environment type | Single instance (public URL, no load balancer) |
| Deployed version | `app-b07b905331f6` |
| Public URL | http://mb-dotnet48-sandbox.eba-ypp8zvmp.us-east-1.elasticbeanstalk.com/ |

The sample is a small ASP.NET 4.8 site (`sample-app/`). It exists only to prove the runtime. It is not a Matchbook application.

---

## Deliverable 2 — Reusable OpenTofu module

The environment above was not left as a console build. It is created and updated from OpenTofu.

```
OpenTofu
    → Elastic Beanstalk application
        → Elastic Beanstalk environment
            → Windows Server + IIS
                → application zip
                    → public URL
```

**Module:** `tofu/modules/beanstalk_environment`  
**Sandbox stack:** `tofu/environments/sandbox`

The four required parameters, with the values used in sandbox:

| Parameter | Variable | Sandbox value |
| --- | --- | --- |
| Application name | `application_name` | `matchbook-dotnet48-sample` |
| Environment | `environment` | `mb-dotnet48-sandbox` |
| Instance type | `instance_type` | `t3.micro` |
| Platform version | `platform_version` | `64bit Windows Server 2022 v2.23.4 running IIS 10.0` |

Changing any of those is a `terraform.tfvars` edit and `tofu apply`. The module is not rewritten.

### Reproduce the sandbox environment

From `tofu/environments/sandbox`, with AWS credentials for account `178231953614`:

```bash
/home/dev/Desktop/matchbook/bin/tofu init
/home/dev/Desktop/matchbook/bin/tofu apply
```

OpenTofu prints `endpoint_url` when it finishes. First Windows boot is typically 10–20 minutes.

### Substitute a real application later

Keep the same application name, environment, instance type, and platform version. Point the stack at a new zip instead of rebuilding Elastic Beanstalk by hand.

| What you receive | What you set in `terraform.tfvars` |
| --- | --- |
| Sample (current) | `artifact_format = "sample"` |
| Zipped publish output (`web.config`, `bin/`, site files) | `artifact_format = "publish_zip"` and `source_bundle_path` |
| Azure DevOps Web Deploy package | `artifact_format = "webdeploy"` and `source_bundle_path` |

Drop the file in `artifacts/incoming/`, update those two settings, run `tofu apply`. Connection strings and similar settings go in `app_environment_variables` — still not a rebuild.

---

## IIS and platform findings

These are the points that mattered in this sandbox. They should be read before anyone deploys a second application onto the same platform.

### Platform version

- **Windows Server 2022 + IIS 10.0** is the stack in use (`v2.23.4`).
- 2022 ships **.NET Framework 4.8.1**, which runs 4.8 applications. The live page confirms the sample runs as 4.8.
- Windows Server 2019 ships 4.8 natively; 2016 retires on 30 September 2026 and should not be used.
- Pin `platform_version` to the full solution-stack name. If it is left unset, AWS can move the environment onto a newer patch (for example `v2.23.5`) without an explicit decision.

### IIS configuration that was required

Windows Elastic Beanstalk does **not** copy a raw `.aspx` zip into IIS on its own. A bundle without `aws-windows-deployment-manifest.json` fails at deploy time.

The working sample bundle includes:

| File | Why it is there |
| --- | --- |
| `web.config` | `targetFramework="4.8"`; default documents `Default.htm` then `Default.aspx` |
| `Default.htm` | `GET /` returns 200. Without it, IIS returns **403.14** (no default document) |
| `Default.aspx` | Compiles on IIS and reports CLR / Framework / target |
| `aws-windows-deployment-manifest.json` | `"architecture": 64`. The default is 32-bit PowerShell; IIS administration then fails with `REGDB_E_CLASSNOTREG` |
| `install.ps1` | Copies the site — including folders such as `bin/` — into `C:\inetpub\wwwroot` |
| `restart.ps1` | Starts `WAS` and `W3SVC` and exits 0. `iisreset` / application-pool recycle can stop IIS and fail the deploy |

If `/` returns 403.14 and `/iisstart.htm` returns 200, IIS is up and the application is not in `wwwroot`.

### Environment notes (this account)

- This sandbox rejects `t3.medium` (“not eligible for Free Tier”). Use `t3.micro` here. A non-restricted account can raise `instance_type` without changing the module.
- Windows images need a larger root volume (module default 35 GiB).
- Two IAM roles are created: an instance profile (`AWSElasticBeanstalkWebTier`, SSM) and a service role (enhanced health, managed updates). The versions bucket name must start with `elasticbeanstalk-`.
- Default is **single instance** (Elastic IP, no load balancer). `environment_type = "LoadBalanced"` is a variable, not a new module.

A longer engineering log is in `docs/gotchas.md`.

---

## Repository map

| Path | What it is |
| --- | --- |
| `sample-app/` | Sample .NET 4.8 site used for the proof |
| `tofu/modules/beanstalk_environment/` | Reusable module (IAM, S3 versions, Beanstalk application + environment) |
| `tofu/environments/sandbox/` | Sandbox values and `tofu apply` entry point |
| `tofu/environments/sandbox/terraform.tfvars` | The four parameters plus optional artifact swap |
| `docs/gotchas.md` | Detailed IIS / platform notes |
| `artifacts/incoming/` | Drop folder for a later application zip |

---

## What this does not include

These items are **not** part of this handover. The module is already shaped so they do not require rebuilding Beanstalk.

- Matchbook source code or a Matchbook deployable artifact
- Redis, databases, or other backing services
- Production sizing, load balancing, or HTTPS certificates
- Anything in a non-sandbox AWS account

---

## Acceptance

| Criterion | Result |
| --- | --- |
| Windows Elastic Beanstalk environment exists in the sandbox | Yes — `mb-dotnet48-sandbox`, Ready / Green |
| Sample .NET Framework 4.8 application is deployed | Yes — version `app-b07b905331f6` |
| Application starts on IIS and is reachable on the Beanstalk URL | Yes — HTTP 200 |
| Runtime is verified as .NET Framework 4.8 | Yes — `.NET Framework 4.8.9339.0`, target `4.8` |
| Required IIS configuration is documented | Yes — this document and `docs/gotchas.md` |
| Working platform version is documented, with gotchas | Yes — Windows Server 2022 IIS 10.0 `v2.23.4` |
| Sandbox only; nothing from Matchbook | Yes |
| Setup is reproducible with OpenTofu | Yes — module + sandbox stack |
| Parameterised on application name, environment, instance type, platform version | Yes |
| Later application zip is a substitution, not a rebuild | Yes — `source_bundle_path` / `artifact_format` |
