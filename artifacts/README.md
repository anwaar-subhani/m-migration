# Matchbook artifact intake

Drop the file from Kuldip here. Do not rebuild the Beanstalk environment.

```
artifacts/incoming/
  private-api-publish.zip   # or the Web Deploy package
  web.config                # sidecar, untransformed if they can send it
```

Then edit `tofu/environments/sandbox/terraform.tfvars` (`artifact_format` + `source_bundle_path`) and run `tofu apply` from that directory.

## What to request from Kuldip

Ask for the deployable artifact their existing Azure DevOps release pipeline already produces, **Private API first**.

Specify:

| Item | Why |
| --- | --- |
| One application only (Private API) | Vijay: APIs use Redis for token metadata, not sessions. Avoids Client Portal's hard Redis dependency. |
| Web Deploy package **or** zipped publish output | Beanstalk accepts both; `artifact_format` selects the path. |
| `web.config` alongside the zip | Reveals IIS modules, handlers, COM, session state, and connection-string names before deploy. Prefer the untransformed file. |
| Health check path, if they have one | A no-Redis deploy may only answer this path. |
| IIS modules / COM they expect on the box | URL Rewrite, WebSockets, native DLLs. |

Do not wait on Client Portal. Do not ask them to retarget AWS.

## After it arrives

1. Inspect `web.config` first (modules, `sessionState`, COM, connection strings).
2. Set `artifact_format` to `publish_zip` or `webdeploy`.
3. `tofu apply` — same application, environment, instance type, and platform version.
4. Record what breaks in `docs/gotchas.md` (Matchbook findings). A health-check-only response without Redis is expected.
