# SucceedAI Landing Page

Static GitHub Pages site for `https://succeed.pierrehenry.dev`.

## Repository Layout

```text
/
  CNAME
  index.html
  assets/
  privacy/index.html
  support/index.html
```

## Publish

GitHub Pages should publish directly from:

- Branch: `main`
- Folder: `/ (root)`

## Custom Domain

`CNAME` must contain:

```text
succeed.pierrehenry.dev
```

## Update From Source Repository

This repository is expected to receive the built static site from:

- `https://github.com/SucceedAI/macOS-Desktop-App`
- source path: `docs/`

Typical update flow:

```bash
rsync -av --delete <source-repo>/docs/ <landing-page-repo>/
git add .
git commit -m "Publish landing page updates for GitHub Pages"
git push origin main
```
