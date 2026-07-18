# SucceedAI Landing Page Deployment

This folder documents how to publish the generated landing page to the public GitHub Pages repository:

- Repository: `https://github.com/SucceedAI/Landing-page`
- Production domain: `https://succeed.pierrehenry.dev`

## Source Of Truth

The deployable site lives in:

- `docs/index.html`
- `docs/privacy/index.html`
- `docs/support/index.html`
- `docs/assets/*`
- `docs/CNAME`

`docs/` is the publishable output.

`Marketing/landing-page/index.html` is the editable marketing source used for content iteration and review.

## Recommended Publishing Model

Use the `SucceedAI/Landing-page` repository as the public GitHub Pages repository.

Do not add a build pipeline unless you need automatic cross-repo sync. The site is static HTML and can be published directly from the branch.

## Files To Copy

Copy the contents of `docs/` into the root of the `Landing-page` repository so the result looks like this:

```text
/
  CNAME
  index.html
  assets/
  privacy/index.html
  support/index.html
```

## Manual Sync Commands

From this repository:

```bash
git clone git@github.com:SucceedAI/Landing-page.git /tmp/SucceedAI-Landing-page
rsync -av --delete docs/ /tmp/SucceedAI-Landing-page/
cd /tmp/SucceedAI-Landing-page
git status
git add .
git commit -m "Publish landing page updates for GitHub Pages"
git push origin main
```

Notes:

- `rsync --delete` keeps the Pages repository aligned with `docs/`.
- Keep the `CNAME` file in the Pages repository root.
- The Pages repository should not contain source-only files from the app repository.

## GitHub Pages Setup

In `SucceedAI/Landing-page`:

1. Go to `Settings` -> `Pages`
2. Set `Source` to `Deploy from a branch`
3. Select:
   - Branch: `main`
   - Folder: `/ (root)`
4. Set the custom domain to `succeed.pierrehenry.dev`
5. Enable `Enforce HTTPS` after the certificate is issued

No GitHub Actions workflow is required for this setup.

## Cloudflare DNS Setup

In Cloudflare DNS for `pierrehenry.dev`, add:

```text
Type: CNAME
Name: succeed
Target: succeedai.github.io
Proxy status: DNS only
```

Notes:

- Start with `DNS only`, not proxied.
- GitHub Pages validates the domain more reliably that way.
- After DNS propagation, GitHub Pages should issue the TLS certificate automatically.

## Optional Automation

If you want automatic sync from this repository to `SucceedAI/Landing-page`, use the optional workflow template in:

- `Marketing/landing-page/sync-to-pages-repo.yml`

That workflow is optional. Use it only if you want `docs/` to remain the single source of truth and do not want to copy files manually.
