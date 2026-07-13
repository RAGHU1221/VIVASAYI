# Deployment Guide: GitHub (APK build) + InfinityFree (php_api + admin_panel)

This guide covers two independent things:

1. Pushing this repo to GitHub so GitHub Actions automatically builds the Flutter release APK.
2. Uploading `php_api` and `admin_panel` to InfinityFree free hosting.

---

## Part 1 — Push to GitHub and get the APK

1. Create a new empty repository on GitHub (no README/license, so it stays empty): `https://github.com/new`
2. In this project folder, set your git identity if not already set:
   ```
   git config user.name "Your Name"
   git config user.email "raghubathi91@gmail.com"
   ```
3. Commit and push:
   ```
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/<your-username>/<your-repo>.git
   git push -u origin main
   ```
4. (Optional but needed for the app to reach your live API) In the GitHub repo, go to **Settings → Secrets and variables → Actions → Variables** and add a repository variable:
   - Name: `API_BASE_URL`
   - Value: `https://vivasayi.site.je` (your InfinityFree URL from Part 2 — currently `vivasayi.site.je`)
5. Go to the **Actions** tab of your repo. Two workflows will run automatically on push:
   - **Build Flutter APK** — builds the release APK.
   - **Package PHP API for InfinityFree** — builds `vendor/` via Composer and zips `php_api` ready to upload.
6. Once a workflow run finishes (green check), open it and download the artifact at the bottom:
   - `vivasayi-release-apk` → `app-release.apk` (install this on an Android phone).
   - `php_api_infinityfree` → `php_api_infinityfree.zip` (upload this in Part 2, no local PHP/Composer needed).
7. Any future push to `main` that touches `flutter_app/` or `php_api/` re-runs the relevant workflow automatically.

---

## Part 2 — Upload to InfinityFree

1. Sign up / log in at `https://infinityfree.net` and create a new hosting account (you'll get a free subdomain like `yourname.infinityfreeapp.com`, or connect your own domain).
2. In the InfinityFree **Control Panel (vPanel)**:
   - **MySQL Databases** → create a database. Note the DB host (e.g. `sqlXXX.infinityfree.com`), database name, username, password.
   - **PHP Version** (under Software/Config) → pick the highest available (8.1 or 8.2). This project's `composer.json` was set to `^8.1` so it works on either.
3. **Import the schema**: open **phpMyAdmin** from the vPanel, select your database, go to **Import**, and upload `database/schema.sql`, then `database/seed.sql` if you want sample data.
4. **Prepare the `.env` for production** (do this on your machine first, don't commit it):
   - Copy `php_api/.env.example` to a new file named `.env`.
   - Fill in the InfinityFree DB values and a strong JWT secret:
     ```
     APP_ENV=production
     APP_DEBUG=false
     APP_URL=https://vivasayi.site.je
     DB_HOST=sqlXXX.infinityfree.com
     DB_PORT=3306
     DB_DATABASE=epiz_xxxxx_dbname
     DB_USERNAME=epiz_xxxxx
     DB_PASSWORD=your_db_password
     JWT_SECRET=<generate a long random string>
     CORS_ALLOWED_ORIGINS=*
     ```
5. **Upload via FTP** (use FileZilla or InfinityFree's built-in Online File Manager). InfinityFree's FTP credentials are shown in the vPanel under "FTP Details".
   - InfinityFree serves your site from the `htdocs` folder.
   - Unzip `php_api_infinityfree.zip` (downloaded in Part 1) locally — it already contains `vendor/`, `src/`, `public/`, `composer.json`, `.htaccess` inside `public/`.
   - Upload so that the **contents of `php_api/public/`** land directly in `htdocs/` (this keeps your API URL clean, e.g. `https://vivasayi.site.je/farmers`), and upload `src/`, `vendor/`, `composer.json` one level above `htdocs` if your plan allows it, or alongside `public`'s contents inside `htdocs` if not — either way `public/index.php`'s `require_once __DIR__ . '/../vendor/autoload.php'` must be able to reach `vendor/` one directory above wherever `index.php` ends up.
   - Simplest approach on InfinityFree (only `htdocs` is web-accessible, nothing above it): upload the **entire unzipped `php_api` folder** into `htdocs/api/` (so `vendor/`, `src/`, `public/` all sit under `htdocs/api/`), then point your domain/API calls at `https://vivasayi.site.je/api/public/`. Alternatively add a `htdocs/api/.htaccess` redirect if you want a cleaner URL.
   - Upload your production `.env` file into that same `php_api` folder (next to `composer.json`), via FTP — never commit it to GitHub.
6. **Upload `admin_panel`**: upload `admin_panel/index.html` into `htdocs/admin/` (or wherever you prefer) so it's reachable at `https://vivasayi.site.je/admin/`.
7. **Test**: visit your API URL in a browser or with curl — you should get a JSON response (or a 404 JSON from the router) rather than a PHP error. If you see a blank page or 500 error, double check the `vendor/` path and that `APP_DEBUG=true` temporarily to see the real error message, then set it back to `false`.

---

## Notes / gotchas

- InfinityFree's free plan has **no SSH access**, so Composer must run elsewhere — that's exactly what the `Package PHP API for InfinityFree` GitHub Action does for you.
- Free InfinityFree accounts get suspended after ~14 days of zero traffic; log in occasionally or upgrade if this app needs to stay live.
- `CORS_ALLOWED_ORIGINS=*` is fine for testing; tighten it once you know your admin panel / app domains.
