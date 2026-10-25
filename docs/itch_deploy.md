# Browser build and itch.io upload

After this workflow is merged, game changes pushed to `main` run the local quality gate, export Web and upload to [Spiders on itch.io](https://eeaeau.itch.io/spiders). Documentation-only pushes are skipped. Deployments run in order so an older build cannot overwrite a newer one.

## One-time configuration

Add these encrypted **Actions secrets** to `Eeaeau/weave`:

- `GDSYNC_PUBLIC_KEY` and `GDSYNC_PRIVATE_KEY`: runtime project keys for online-capable exports.
- `BUTLER_API_KEY`: the itch.io upload key. It is available only to configuration checks and the upload step, never to the Godot export.

Never put credential values in workflow files, repository variables or commits. GD-Sync bundles its runtime project keys in player builds as required by the SDK; dashboard credentials and the itch.io upload key must stay private.

The upload destination defaults to `eeaeau/spiders:html5`. Optional Actions variables `ITCH_USER` and `ITCH_GAME` can override the account/game slugs.

After the first upload, set the itch.io project type to **HTML** and mark the uploaded channel **HTML5 / Playable in browser** on the game's edit page.

## Manual builds

Open **Actions > Build and deploy web to itch.io > Run workflow**. Any branch can create a downloadable artifact. Publishing is allowed only from `main`: select **deploy** and optionally choose a channel. No feature-branch push publishes a build.

Artifacts are retained for seven days. The deployed build is tagged with its source commit's short SHA. Missing credentials fail before tool installation; failed checks prevent uploading.

## Local export

The Web preset exports from Godot 4.7.2 into ignored `build/web/`, excludes tests and disables threading so ordinary itch.io hosting works without cross-origin isolation headers.

```powershell
New-Item -ItemType Directory -Force build/web | Out-Null
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --export-release Web build/web/index.html
```
