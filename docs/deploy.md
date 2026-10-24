# Deploy

The repo is the source of truth. Two targets:

| Target | What it is | Public? |
|---|---|---|
| Local Gitea (`127.0.0.1:3000`) | My own remote, full history | No, tailnet only |
| GitHub (`github.com/Elio-AGR/elio-s-homelab`) | The copy a recruiter can open | Yes |
| GitHub Pages | `site/` published as a static site | Yes |

## 1. Create the GitHub repo

Empty repository, no README, no .gitignore, name `elio-s-homelab`.

## 2. Push

```bash
git remote add github git@github.com:Elio-AGR/elio-s-homelab.git
git push -u github main
```

If SSH is not set up, use HTTPS with a personal access token instead:

```bash
git remote add github https://github.com/Elio-AGR/elio-s-homelab.git
git push -u github main   # username: Elio-AGR, password: <token>
```

## 3. Enable Pages

Settings → Pages → **Source: GitHub Actions**. The workflow in
`.github/workflows/pages.yml` runs on every push that touches `site/`, uploads the
directory as an artifact and publishes it.

URL: <https://elio-agr.github.io/elio-s-homelab/>

No build step, no dependencies, so the deployment is just a file copy.

## 4. Keep both remotes in sync

```bash
git push origin main && git push github main
```

Or push to one and let the other pull. Twenty commits of history is not worth a CI sync job.

## Notes

- Since Pages serves only `site/`, links from the UI to `../docs/*.md` are rewritten at
  runtime to GitHub blob URLs (see `fixDocLinks()` in `site/app.js`). Locally they resolve
  as normal relative paths.
- `.nojekyll` is not needed: no files start with an underscore.
- Custom domain: optional, costs a domain. Pages gives TLS for free either way.
- The repo stays sanitized: no hostnames, tailnet addresses, chat IDs or tokens. Run
  `make check` before any push.
