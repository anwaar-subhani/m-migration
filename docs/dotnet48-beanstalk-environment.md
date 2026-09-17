# .NET 4.8 on Elastic Beanstalk

Working Windows environment in the **sandbox account only**. No Matchbook application, artifact, or account was used.

## Working environment

Open this URL. The app loads. **Default.aspx** shows .NET Framework 4.8.

**http://mb-dotnet48-sandbox.eba-ypp8zvmp.us-east-1.elasticbeanstalk.com/**

| | |
| --- | --- |
| AWS account | `178231953614` (sandbox), `us-east-1` |
| Application | `matchbook-dotnet48-sample` |
| Environment | `mb-dotnet48-sandbox` (`e-kbthhytguj`), Ready / Green |
| Platform | `64bit Windows Server 2022 v2.23.4 running IIS 10.0` |
| Instance | `t3.micro`, single instance |
| Home page | `GET /` → 200 |
| Runtime proof | CLR `4.0.30319.42000`, `.NET Framework 4.8.9339.0`, target `4.8` |

The site is a small sample in `sample-app/`. It only proves the platform can run .NET Framework 4.8 on IIS.

## Platform version

- This environment uses **Windows Server 2022 / IIS 10.0**, stack **v2.23.4**.
- 2022 ships **.NET Framework 4.8.1**, which runs 4.8 apps. The live page confirms the sample runs as **4.8**.
- Windows Server **2019** ships 4.8 natively. **2016** retires 30 September 2026 — do not use it.
- Pin the full solution-stack name. If you do not, AWS can move the environment to a newer patch (for example v2.23.5) without an explicit decision.

This sandbox account rejects `t3.medium` (Free Tier). Use `t3.micro` here.

## IIS configuration

Windows Elastic Beanstalk does **not** copy a raw `.aspx` zip into IIS. The bundle needs `aws-windows-deployment-manifest.json`.

| File | Why |
| --- | --- |
| `web.config` | `targetFramework="4.8"`; default documents `Default.htm` then `Default.aspx` |
| `Default.htm` | `GET /` returns 200. Without it, IIS returns **403.14** |
| `Default.aspx` | Compiles on IIS and reports CLR / Framework / target |
| `aws-windows-deployment-manifest.json` | `"architecture": 64`. Default is 32-bit PowerShell; IIS then fails with `REGDB_E_CLASSNOTREG` |
| `install.ps1` | Copies the site into `C:\inetpub\wwwroot` (including folders such as `bin/`) |
| `restart.ps1` | Starts `WAS` and `W3SVC` and exits 0. `iisreset` / app-pool recycle can stop IIS and fail the deploy |

If `/` is 403.14 and `/iisstart.htm` is 200, IIS is up and the application is not in `wwwroot`.
