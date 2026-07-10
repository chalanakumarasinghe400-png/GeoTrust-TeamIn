# GSMB Admin Dashboard

Standalone admin dashboard website for the GeoTrust app. It includes:

- Live-style overview cards
- Map view for locations and incident hotspots
- Charts for overloads, fraud flags, and transport status
- Search, region, and risk filters
- A detail panel for flagged locations

## Run locally

Open `index.html` directly in a browser, or serve the folder with a static server:

```bash
python3 -m http.server 4173
```

Then visit `http://localhost:4173` from inside this folder.

## Data hookup

Replace the sample dataset in `app.js` with your GSMB backend or Supabase records when ready.
