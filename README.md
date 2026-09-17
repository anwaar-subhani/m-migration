# Windows Elastic Beanstalk + .NET Framework 4.8

Sandbox proof that AWS Elastic Beanstalk runs .NET Framework 4.8 on Windows/IIS, plus a reusable OpenTofu module for that environment.

**Client handover:** [docs/handover-dotnet48-elastic-beanstalk.md](docs/handover-dotnet48-elastic-beanstalk.md)

Live check: [http://mb-dotnet48-sandbox.eba-ypp8zvmp.us-east-1.elasticbeanstalk.com/](http://mb-dotnet48-sandbox.eba-ypp8zvmp.us-east-1.elasticbeanstalk.com/)

| Path | Purpose |
| --- | --- |
| `docs/handover-dotnet48-elastic-beanstalk.md` | What was delivered, how to verify, how to reproduce |
| `docs/deploy-elastic-beanstalk.md` | Step-by-step deploy on Elastic Beanstalk |
| `docs/engineering-validation.md` | 5-area validation: plan no-op, live artifact swap, failures, production gaps |
| `docs/gotchas.md` | IIS and platform notes |
| `sample-app/` | Sample ASP.NET 4.8 site |
| `tofu/modules/beanstalk_environment/` | Reusable Beanstalk module |
| `tofu/environments/sandbox/` | Sandbox stack (`tofu apply` here) |
