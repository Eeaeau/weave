# Browser build and itch.io upload

The repository includes a manual GitHub Actions workflow at `.github/workflows/itch-web.yml`. Running it with **deploy = false** checks the project, exports Web, and saves an artifact. Running it with **deploy = true** also uploads the build to itch.io. No upload runs on a normal push.

## One-time setup in each jam repository

1. Create the game page on itch.io. Butler cannot create the page. Its URL supplies the user and game slug, for example `person.itch.io/my-game` means `ITCH_USER=person` and `ITCH_GAME=my-game`.
2. In the GitHub repository, add Actions **variables** `ITCH_USER` and `ITCH_GAME`.
3. Add an Actions **secret** named `BUTLER_API_KEY` from your itch.io API keys. Never commit the key or paste it into a workflow file.
4. Open **Actions > Build web and optionally deploy to itch.io > Run workflow**. Leave **deploy** off for a preview build. Turn it on and choose a channel such as `html5` to upload.
5. After the first upload, set the itch.io project type to **HTML** and mark the uploaded channel **HTML5 / Playable in browser** on the game's edit page.

The Web preset exports from Godot 4.7.2 into `build/web/`. The workflow installs Godot and export templates, runs `python3 tools/check.py`, uploads the web artifact, and uses official butler to push when deploy is selected. Butler tags the upload with the source commit's short SHA. Web exports use the Compatibility renderer and exclude test scripts. The preset has web threading disabled so the game does not require cross-origin isolation headers.

Local export with installed export templates:

```powershell
New-Item -ItemType Directory -Force build/web | Out-Null
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --export-release Web build/web/index.html
```

If the jam needs desktop downloads, add a Windows/Linux/macOS export preset and a separate channel. Weave keeps this workflow Web-only until the target platforms are known.
