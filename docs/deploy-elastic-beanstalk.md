# Deploy a .NET Framework 4.8 app to Windows Elastic Beanstalk

Step-by-step for this repository. The path is **OpenTofu → Elastic Beanstalk application → environment → Windows/IIS → zip → public URL**.

This is the same process used for the sandbox environment:

http://mb-dotnet48-sandbox.eba-ypp8zvmp.us-east-1.elasticbeanstalk.com/

---

## What you need first

1. **AWS sandbox account** `178231953614`, region `us-east-1`.  
   Do not use a Matchbook or NMD account for this flow.
2. **IAM user credentials** (not the account root user).  
   On this machine the default profile is IAM user `radiate-dev`. Confirm with:

   ```bash
   aws sts get-caller-identity
   ```

   You should see `"Account": "178231953614"` and an ARN like `arn:aws:iam::178231953614:user/<name>`.
3. **Default VPC** in `us-east-1`. Elastic Beanstalk uses it when no VPC is specified.
4. **OpenTofu** 1.6+ (this repo’s binary is `bin/tofu`).
5. **Python 3** (only needed if you later wrap a publish zip).
6. Permission to create IAM roles, S3 buckets, Elastic Beanstalk applications/environments, and EC2 instances.

AWS CLI credentials live in `~/.aws/credentials` profile `[default]`. OpenTofu uses that chain because `aws_profile` is unset.

---

## What gets created

| Resource | Name in sandbox |
| --- | --- |
| Elastic Beanstalk application | `matchbook-dotnet48-sample` |
| Elastic Beanstalk environment | `mb-dotnet48-sandbox` |
| Platform | `64bit Windows Server 2022 v2.23.4 running IIS 10.0` |
| EC2 | one `t3.micro` (SingleInstance, Elastic IP, no load balancer) |
| S3 versions bucket | `elasticbeanstalk-matchbook-dotnet48-sample-178231953614` |
| IAM instance profile | `mb-dotnet48-sandbox-eb-ec2` |
| IAM service role | `mb-dotnet48-sandbox-eb-service` |

First Windows boot is typically **10–20+ minutes**. Later zip-only updates are much faster.

---

## Step 1 — Confirm the application bundle

Windows Beanstalk will not copy a raw `.aspx` zip into IIS. The zip must include a custom deploy.

For the sample, that is already in `sample-app/`:

| File | Role |
| --- | --- |
| `web.config` | `targetFramework="4.8"`; default documents |
| `Default.htm` | Makes `GET /` return 200 |
| `Default.aspx` | Proves .NET Framework 4.8 on IIS |
| `aws-windows-deployment-manifest.json` | `"architecture": 64`; runs the scripts below |
| `install.ps1` | Copies site files into `C:\inetpub\wwwroot` |
| `restart.ps1` | Starts `WAS` / `W3SVC` and exits 0 |
| `uninstall.ps1` | No-op on upgrade |

Do not omit the manifest. Do not set architecture to 32. Do not use `iisreset` in `restart.ps1`.

OpenTofu zips `sample-app/` for you. You do not zip it by hand for the sample path.

---

## Step 2 — Set deploy values

Edit `tofu/environments/sandbox/terraform.tfvars`:

```hcl
application_name = "matchbook-dotnet48-sample"
environment      = "mb-dotnet48-sandbox"
instance_type    = "t3.micro"
platform_version = "64bit Windows Server 2022 v2.23.4 running IIS 10.0"
aws_region       = "us-east-1"
environment_type = "SingleInstance"
artifact_format  = "sample"
```

Notes:

- `environment` must be 4–40 characters (letters, numbers, hyphens).
- This sandbox account rejects `t3.medium` (“not eligible for Free Tier”). Use `t3.micro`.
- Pin the **full** `platform_version` string so AWS does not silently move you to `v2.23.5`.

List available Windows/IIS stacks if you need another version:

```bash
aws elasticbeanstalk list-available-solution-stacks \
  --query "SolutionStacks[?contains(@, 'IIS 10.0')]" \
  --output text
```

---

## Step 3 — Initialise OpenTofu

```bash
cd tofu/environments/sandbox
../../bin/tofu init
```

If you are at the repo root:

```bash
cd /home/dev/Desktop/matchbook/tofu/environments/sandbox
/home/dev/Desktop/matchbook/bin/tofu init
```

This downloads the AWS, archive, and external providers. Run it once per machine (and again if providers change).

---

## Step 4 — Preview the change

```bash
/home/dev/Desktop/matchbook/bin/tofu plan
```

On a first deploy you should see create actions for IAM, S3, the Beanstalk application, application version, and environment.

On a zip-only update you should see a new application version and an in-place environment update — not a new environment.

---

## Step 5 — Apply (this is the deploy)

```bash
/home/dev/Desktop/matchbook/bin/tofu apply
```

Type `yes`, or use `-auto-approve` if you already reviewed the plan.

What OpenTofu does:

1. Creates IAM roles and the instance profile (if they do not exist).
2. Creates the S3 bucket whose name starts with `elasticbeanstalk-`.
3. Zips `sample-app/` (when `artifact_format = "sample"`).
4. Uploads the zip and registers an Elastic Beanstalk application version (`app-<hash>`).
5. Creates or updates the environment onto that version.
6. Waits until the environment is Ready (timeout 45 minutes).

When it finishes, it prints:

```text
endpoint_url    = "http://mb-dotnet48-sandbox.eba-ypp8zvmp.us-east-1.elasticbeanstalk.com"
environment_id  = "e-kbthhytguj"
platform_version = "64bit Windows Server 2022 v2.23.4 running IIS 10.0"
version_label   = "app-........"
```

Read outputs again any time with:

```bash
/home/dev/Desktop/matchbook/bin/tofu output
```

---

## Step 6 — Confirm the environment is Ready

```bash
aws elasticbeanstalk describe-environments \
  --environment-names mb-dotnet48-sandbox \
  --query 'Environments[0].{Status:Status,Health:Health,CNAME:CNAME,VersionLabel:VersionLabel,SolutionStackName:SolutionStackName}'
```

Wait until `Status` is `Ready` and `Health` is `Green`.

Watch events if it sits on `Launching` or `Updating`:

```bash
aws elasticbeanstalk describe-events \
  --environment-name mb-dotnet48-sandbox \
  --max-items 20
```

---

## Step 7 — Verify the application

```bash
URL=$(/home/dev/Desktop/matchbook/bin/tofu output -raw endpoint_url)
curl -sS -D - -o /dev/null "$URL/"
curl -sS "$URL/Default.aspx"
```

Or open the URL in a browser.

| Check | Expected |
| --- | --- |
| `GET /` | HTTP 200 |
| `GET /Default.aspx` | HTTP 200, IIS 10.0 |
| Page body | CLR `4.0.30319.42000`, `.NET Framework 4.8.9339.0`, target `4.8` |

If `/` is **403.14** and `/iisstart.htm` is **200**, IIS is up but the site never landed in `C:\inetpub\wwwroot`. Check the bundle (manifest, `install.ps1`) and Beanstalk events.

---

## Deploy a new version (same environment)

Change files under `sample-app/`, then from `tofu/environments/sandbox`:

```bash
/home/dev/Desktop/matchbook/bin/tofu apply
```

OpenTofu hashes the zip, creates a new version label, and updates the existing environment. You do not recreate IAM, S3, or the environment.

---

## Deploy a different zip (substitution, not a rebuild)

Keep `application_name`, `environment`, `instance_type`, and `platform_version`. Change only the artifact.

**Zipped publish output** (`web.config`, `bin/`, site files):

1. Put the zip (and optional sidecar `web.config`) in `artifacts/incoming/`.
2. In `terraform.tfvars`:

   ```hcl
   artifact_format    = "publish_zip"
   source_bundle_path = "../../../artifacts/incoming/private-api-publish.zip"
   web_config_path    = "../../../artifacts/incoming/web.config"
   ```

3. `tofu apply`.

**Web Deploy package** (`.deploy.cmd` / `parameters.xml`):

```hcl
artifact_format    = "webdeploy"
source_bundle_path = "../../../artifacts/incoming/private-api.webdeploy.zip"
```

Then `tofu apply`.

Optional config (Redis, connection strings) without rebuilding Beanstalk:

```hcl
app_environment_variables = {
  RedisHost = "example.cache.amazonaws.com"
}
```

---

## If you must do it in the AWS console instead

This repo is meant to be applied with OpenTofu. Console equivalent, for reference only:

1. Elastic Beanstalk → Applications → Create application.
2. Platform: **IIS**, Windows Server **2022**, 64-bit, IIS 10.0. Pick the pinned version, not “latest”.
3. Environment type: **Single instance** (sandbox) or load balanced.
4. Instance type: `t3.micro` in this account.
5. Upload a zip that includes `aws-windows-deployment-manifest.json` and the install/restart scripts.
6. Wait for Ready, then open the environment URL.

You still need the same IAM instance profile and service role, and an S3 bucket whose name starts with `elasticbeanstalk-` if the instance uses `AWSElasticBeanstalkWebTier`.

---

## Common failures

| Symptom | Cause | Fix |
| --- | --- | --- |
| `not eligible for Free Tier` | `t3.medium` (or similar) on this account | Set `instance_type = "t3.micro"` |
| Environment Launching, no instance | Instance type rejected, or default VPC missing | Check events; confirm default VPC |
| Deploy `01deploy.ps1` exit `-1` | Zip has no Windows deploy manifest | Use `sample-app/` layout or `artifact_format = "publish_zip"` |
| `REGDB_E_CLASSNOTREG` | 32-bit PowerShell talking to IIS | Manifest `"architecture": 64` |
| HTTP 403.14 on `/` | No default document in `wwwroot` | Include `Default.htm` / defaultDocument in `web.config` |
| IIS down after deploy | `iisreset` or app-pool recycle stopped W3SVC | `restart.ps1` should start WAS/W3SVC and exit 0 |
| Apply longer than 45 minutes | Windows AMI first boot | Wait; check events; do not destroy and recreate yet |

---

## Commands cheat sheet

All from `tofu/environments/sandbox` unless noted.

```bash
aws sts get-caller-identity
/home/dev/Desktop/matchbook/bin/tofu init
/home/dev/Desktop/matchbook/bin/tofu plan
/home/dev/Desktop/matchbook/bin/tofu apply
/home/dev/Desktop/matchbook/bin/tofu output

aws elasticbeanstalk describe-environments --environment-names mb-dotnet48-sandbox
aws elasticbeanstalk describe-events --environment-name mb-dotnet48-sandbox --max-items 20
```

Do not run `tofu destroy` unless you intend to delete the live environment, IAM roles, and versions bucket.
