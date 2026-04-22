# Per Diem Web App (No Device Install)

This is a browser-based app version of your per-diem tracker. End users only open a URL.

## What it does

- Looks up daily FY2026 GSA M&IE by city/state.
- If city is not listed, it tries county fallback:
  - Nominatim geocoding (free)
  - US Census county geographies (free)
- Tracks expenses and shows amount left (green) or overage (red).
- Uses short-term local memory only (auto-prunes anything older than 7 days).
- Starts with one empty expense line and only adds one new empty line when `+ another expense` is clicked.

## Local run

```bash
npm install
npm run dev
```

## Publish to GitHub (web link)

1. Create a GitHub repo and push this folder as the repo root.
2. In GitHub: `Settings -> Pages`, set source to `GitHub Actions`.
3. Push to `main`. The workflow at `.github/workflows/deploy-pages.yml` will build and deploy.
4. Your public link will be:
   - `https://<your-github-username>.github.io/<your-repo-name>/`

## Data file used

- `public/fy2026_master.json` (copied from your provided FY2026 Excel extract)
