# Engineering validation — Windows Elastic Beanstalk + .NET 4.8

This is the self-check at the “sound, reproducible, maintainable, production-aware” bar — not “did the app load.”

Date: 17 September 2026. Account: sandbox `178231953614`, `us-east-1`. Identity: IAM user `radiate-dev` (not root).

---

## 1. Functional correctness — proven

| Check | Evidence |
| --- | --- |
| .NET Framework 4.8 runs | Live `/Default.aspx`: CLR `4.0.30319.42000`, `.NET Framework 4.8.9339.0`, target `4.8` |
| Environment healthy | Ready / Green / HealthStatus Ok |
| Reachable | `GET /` and `GET /Default.aspx` → 200 |
| IIS serving the app | IIS 10.0 compiled ASPX; not `iisstart.htm` |
| Expected artifact | Beanstalk version `app-b07b905331f6` from `sample-app/` |
| Platform understood | Pinned `64bit Windows Server 2022 v2.23.4 running IIS 10.0`. 2022 ships 4.8.1, which runs 4.8. 2016 retires 2026-09-30. AWS already lists v2.23.5 as most recent — that is why the name is pinned. |

URL: http://mb-dotnet48-sandbox.eba-ypp8zvmp.us-east-1.elasticbeanstalk.com/

---

## 2. IaC quality — module vs environment

Reusable: `tofu/modules/beanstalk_environment/` (`main.tf`, `variables.tf`, `outputs.tf`, `iam.tf`).  
This account: `tofu/environments/sandbox/` (`main.tf`, `variables.tf`, `terraform.tfvars`).

| Asked | Variable | Sandbox value |
| --- | --- | --- |
| application_name | `application_name` | `matchbook-dotnet48-sample` |
| environment_name | `environment` (`environment_name` is an alias) | `mb-dotnet48-sandbox` |
| instance_type | `instance_type` | `t3.micro` |
| platform_version | `platform_version` | full solution-stack name above |
| sample_app_artifact | `sample_app_artifact` / `source_bundle_path` / `artifact_format` | `sample` zips `sample-app/` |
| region | `aws_region` | `us-east-1` |
| environment_variables | `app_environment_variables` | `{}` |
| tags | `tags` (merged with Project / Environment / ManagedBy) | defaults |
| health_check | `health_check_path` | `/` — applied only when `environment_type = "LoadBalanced"` |

Another engineer clones the repo, sets AWS credentials for this account, edits `terraform.tfvars`, runs `tofu apply` from `tofu/environments/sandbox`. They do not need the original console/SSM session.

Account facts they still need (not in the module): IAM user, default VPC, Free Tier `t3.micro`, OpenTofu 1.6+.

---

## 3. Reproducibility

**`tofu plan` after a successful apply (17 Sep 2026):** no changes. Infrastructure matches configuration.

**Zip-only updates** (sample → substitution zip → sample) completed with OpenTofu only. Same environment ID `e-kbthhytguj`, same CNAME. No console upload, no SSM, no hand-edited AWS resources.

**`tofu destroy` then `tofu apply` was not run against this live environment.** Recreating Windows Beanstalk changes the `eba-*` CNAME, takes 20–45 minutes, and would destroy the URL used in client handover. That is a deliberate POC boundary, not a missing button. Procedure if it must be done:

```bash
cd tofu/environments/sandbox
/home/dev/Desktop/matchbook/bin/tofu destroy
/home/dev/Desktop/matchbook/bin/tofu apply
```

Then take the new `endpoint_url` from outputs. Do not assume the old URL still works.

**First-boot history (honest):** the original environment was imported while Launching; IIS was started once with SSM; `t3.medium` was rejected by Free Tier. Later applies, including the substitution test, did not repeat those manual steps.

---

## 4. Substitution test — proven on the live environment

Same module, same application, same environment, same instance type, same platform. Only the zip changed.

| Step | Result |
| --- | --- |
| Sample `artifact_format = "sample"` | Original 4.8 page, version `app-b07b905331f6` |
| `artifact_format = "publish_zip"` + `sample_app_artifact` = `artifacts/incoming/substitution-test-publish.zip` | Version `app-86cd954d6c2e`. Page title **SUBSTITUTION-TEST-ARTIFACT**. Still 4.8. Env still `e-kbthhytguj`. |
| Revert to sample, `tofu apply` | Sample page back, version `app-b07b905331f6` again. `tofu plan` → no changes. |

The substitution zip is a **publish output** (web.config + aspx only). OpenTofu wrapped it with the proven IIS custom deploy. That is the Matchbook-shaped path: drop a zip, change two variables, apply.

Matchbook itself is still not deployed. The mechanism is proven. When their artifact arrives, use the same two variables. Redis/session activation is a **config** change (`app_environment_variables`), not a rebuild. A health-check-only response without Redis is expected, not a platform failure.

---

## 5. Failure / edge cases

| Question | What we know |
| --- | --- |
| Invalid artifact | Zip without `aws-windows-deployment-manifest.json` fails at `01deploy.ps1` exit `-1`. Events show it. Environment stays on the previous version if the deploy aborts. |
| Platform version change | Data source already sees **v2.23.5**. We pin **v2.23.4**. Unset `platform_version` and the next apply can move the stack. Do not treat “latest IIS 10.0” as stable. |
| Wrong IIS config | `403.14` on `/` + `200` on `/iisstart.htm` = IIS up, app not in `wwwroot`. `REGDB_E_CLASSNOTREG` = 32-bit PowerShell; manifest must be `"architecture": 64`. `iisreset` in restart can stop W3SVC. |
| Where logs go | Beanstalk **Events** (deploy/health). On the instance: `C:\inetpub\logs\LogFiles` (IIS), `C:\Windows\System32\LogFiles\HTTPERR`, `C:\cfn` / EB deploy logs under `C:\Program Files\Amazon\ElasticBeanstalk`. Console: environment → Logs → Request logs. SSM Session Manager if the instance profile is intact. |
| Environment health | `aws elasticbeanstalk describe-environments` (Status, Health, HealthStatus) plus enhanced health. Underneath: one EC2, EIP, security group, CloudFormation stack. **No ALB** on SingleInstance. |
| Recreate | `tofu destroy` / `tofu apply` — see §3. |
| Swap artifact | `sample_app_artifact` + `artifact_format` — proven §4. |
| What EB creates here | EC2 instance, Auto Scaling launch template (min=max=1), Elastic IP, security group, CloudFormation, S3 version object. Not an ELB. |
| Manually configured now | Nothing required for apply. Historical SSM/import is not part of the current path. |
| Environment-specific | `terraform.tfvars` |
| Reusable | `tofu/modules/beanstalk_environment` |

### Diagnosis path

```
OpenTofu plan/apply error
  → IAM / S3 / Beanstalk API (wrong account, Free Tier instance type)
Elastic Beanstalk events (Updating / Degraded)
  → version deploy failed (manifest, scripts, timeout)
EC2 / Windows
  → instance replaced, status checks, SSM
IIS (W3SVC / WAS)
  → 403.14, iisstart.htm, wwwroot empty
.NET 4.8 application
  → yellow ASP.NET error, web.config, missing bin/, Redis/session later
```

---

## Design decisions (why, not how many .tf files)

- **OpenTofu owns the environment** so the Matchbook zip is a substitution, not a console rebuild.
- **SingleInstance** for sandbox cost; `LoadBalanced` is a variable for later.
- **t3.micro** because this account rejects larger Free-Tier-ineligible types.
- **Pin the full solution stack** so a silent v2.23.4 → v2.23.5 does not happen.
- **Custom Windows deploy manifest** because a raw aspx zip does not land in IIS on this platform.
- **S3 bucket name starts with `elasticbeanstalk-`** so `AWSElasticBeanstalkWebTier` can `s3:Get*`.
- **Do not destroy the live proof URL** until a second environment exists or the CNAME change is accepted.

---

## Production gaps (POC does not include these)

HTTPS / custom domain, private subnets, ALB + autoscaling, log drain and alarms, remote state locking, secrets manager, Redis/DB, IAM tighter than EB managed policies, instance size for real IIS load, Windows patching policy.

That boundary is intentional. The module already accepts `environment_type`, `health_check_path`, `app_environment_variables`, and `option_settings` so those are additions, not a rewrite.

---

## Self-test

**If Andy hands over a different .NET 4.8 zip tomorrow, can it deploy with existing OpenTofu without rebuilding infra?**  
Yes. Set `artifact_format` and `sample_app_artifact`, `tofu apply`. Demonstrated with `artifacts/substitution-test/`.

**If it fails, where do you look?**  
OpenTofu → Beanstalk events → EC2/Windows → IIS → the application. Table in §5.

**Mature bar:** working deploy → reproducible IaC (`plan` no-op) → artifact substitution (live) → current path has no required manual steps → IIS/platform gotchas documented → production gaps named.  
`destroy`/`apply` of the client URL is the remaining expensive test; it is documented, not faked.
