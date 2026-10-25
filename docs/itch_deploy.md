# Browser builds and itch.io deployment

Game changes merged to `main` run checks, export Web and upload to [Spiders on itch.io](https://eeaeau.itch.io/spiders). Documentation-only pushes are skipped. Uploads are serialized.

## Credential boundaries

Configure these GitHub **environments**, each with a selected deployment **branch** rule matching only `main`:

- `spiders-production`: encrypted `GDSYNC_PUBLIC_KEY` and `GDSYNC_PRIVATE_KEY` secrets, available only to the production build job.
- `itch-production`: encrypted `BUTLER_API_KEY`, available only to the isolated uploader. Use the `wharf` token created by `butler login`.

Do not store production credentials as repository-level secrets. A workflow edited on a feature branch could request repository secrets. Environment branch rules enforce the boundary outside the workflow file. Protect `main` and require owner review of workflow/CODEOWNERS changes.

The uploader downloads this run's checked artifact. It does no source checkout and runs no game code. Butler is pinned to a version and verified SHA-256 checksum before the upload token is supplied. The token never reaches the build job or game export.

GD-Sync requires both runtime keys in the exported game; players can extract them. Encrypted CI storage keeps them out of source and logs, not out of released clients. Dedicate the pair to Spiders, avoid an unused database link, and monitor service usage. Keep dashboard credentials and the itch upload token private.

## Manual builds

Open **Actions > Build and deploy web to itch.io > Run workflow**. Feature branches build a local-play preview without production keys, using the empty `spiders-preview` environment. Only `main` can build with production keys or publish; select **deploy** to upload a manual main build.

The destination is `eeaeau/spiders:html5`. Artifacts are kept for one day; deployed builds are tagged with the source commit's short SHA. Failed checks prevent uploading.

After the first upload, set the itch.io project type to **HTML** and mark the uploaded channel **HTML5 / Playable in browser**.

## Secret maintenance

Use `gh secret set NAME --repo Eeaeau/weave --env ENVIRONMENT`, supplying the value through stdin. Never put values in arguments, repository variables, commits or logs.

If the itch token leaks, revoke it on itch.io, run `butler login` again, and replace the environment secret. A GD-Sync key replacement requires rebuilding clients; old builds stop connecting after the old pair is revoked.

## Local export

The Web preset uses Godot 4.7.2, excludes tests and disables threading for ordinary itch.io hosting. Local runtime keys come from ignored `addons/GD-Sync/keys.cfg` or the two `GDSYNC_*` environment variables.

```powershell
New-Item -ItemType Directory -Force build/web | Out-Null
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --export-release Web build/web/index.html
```
