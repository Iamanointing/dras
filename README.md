# CRE Result Archiving System (DRAS)

PHP + MySQL app for course results, lecturer uploads (CA / exam), admin approval, and transcript requests.

---

## Local development (XAMPP)

1. Copy the project to `htdocs/DRAS` (or any folder under `htdocs`).
2. Create the database and import **`sql/install_full.sql`** (phpMyAdmin or MySQL CLI).
3. Default app URL: `http://localhost/DRAS/`  
   - `includes/config.php` uses `DRAS_WEB_BASE` **`/DRAS`**. If your folder name differs, change `DRAS_WEB_BASE` to match (e.g. `/MyFolder`).
4. DB defaults in `includes/db_connect.php`: `localhost`, `root`, no password, database `result_archiving_db`.
5. Demo users (after import): see **`sql/demo_credentials.txt`**. Admin email stays **`admin@cre.edu`** (password from your original setup / seed).

---

## Hosting on InfinityFree

InfinityFree provides free PHP hosting and MySQL. Your site is usually at:

`https://YOURNAME.epizy.com`  
(or a custom domain you attach in the panel.)

### Step 1 — Create an account and site

1. Go to [infinityfree.com](https://www.infinityfree.com) and sign up.
2. Create a **hosting account** and note your **subdomain** (e.g. `yoursite.epizy.com`).
3. Open the **Control Panel** (cPanel-style) for that account.

### Step 2 — Create a MySQL database

1. In the panel, open **MySQL Databases** (or **Remote MySQL** / **Database** section).
2. Create a **database** and a **user**, and assign the user to the database with **ALL PRIVILEGES**.
3. Copy and save these four values (you will need them exactly):

   - **MySQL hostname** (e.g. `sql123.epizy.com` — **not** `localhost` on InfinityFree)
   - **Database name** (often like `epiz_xxxxxx_dbname`)
   - **Username**
   - **Password**

### Step 3 — Upload the application files

1. Open **Online File Manager** or use **FTP** (FTP details are in the control panel).
2. Go to **`htdocs`** (sometimes shown as `public_html` or the root of your site).
3. Upload **all project folders and files**, keeping the same structure:

   - `admin/`, `auth/`, `lecturer/`, `student/`, `includes/`, `assets/`, `uploads/`, `sql/`, `index.php`, `style.css`, etc.

4. **Important — URL path (`DRAS_WEB_BASE`):**

   - If the app is **at the site root** (files directly inside `htdocs`, so the homepage is `https://yoursite.epizy.com/index.php`):  
     set `DRAS_WEB_BASE` to **`''`** (empty string).
   - If you put everything inside a subfolder, e.g. `htdocs/DRAS/`, then the base path is **`/DRAS`**.

   You set this in **`includes/config.local.php`** (next step), not by guessing from FTP paths alone.

### Step 4 — Configure `config.local.php` (production)

1. On your PC, copy **`includes/config.local.example.php`** to **`includes/config.local.php`**.
2. Edit **`includes/config.local.php`** on the server (or upload it after editing):

   - **`DRAS_WEB_BASE`**: `''` for root install, or `'/YourSubfolder'` if the app lives in a subfolder.
   - **`DRAS_DB_HOST`**: the MySQL hostname from the panel.
   - **`DRAS_DB_USER`**, **`DRAS_DB_PASS`**, **`DRAS_DB_NAME`**: from the panel.

3. **Do not** commit `config.local.php` to public Git repos (it contains passwords). It is listed in **`.gitignore`**.

### Step 5 — Import the database

1. Open **phpMyAdmin** from the InfinityFree control panel (or use **Remote MySQL** import if offered).
2. Select **your** database (the one matching `DRAS_DB_NAME`).
3. Import **`sql/install_full.sql`** (this drops/creates `result_archiving_db` inside that database — see note below).

**Note:** InfinityFree often gives you **one** database with a fixed name. If `install_full.sql` uses `CREATE DATABASE result_archiving_db`, it may fail or be blocked.

- **Option A:** In phpMyAdmin, select your existing empty database, then edit the SQL file: remove the `DROP DATABASE` / `CREATE DATABASE` / `USE` lines and run only the `CREATE TABLE` + `INSERT` parts **against that database**.
- **Option B:** Use a trimmed installer that only runs `USE` your DB name — same as editing the file to replace `result_archiving_db` with your actual database name in `USE` and in any references.

After import, ensure `includes/db_connect.php` (via `config.local.php`) points to **that** database name.

### Step 6 — PHP version and folders

1. In the control panel, set **PHP** to a recent version (PHP **8.0+** recommended if available).
2. Ensure the folder **`uploads/receipts/`** exists and is **writable** by PHP (for transcript receipt uploads). Create it if missing; the app may create it on first upload if permissions allow.

### Step 7 — HTTPS and first test

1. Enable **Free SSL** / **HTTPS** in the panel if available.
2. Visit `https://yoursite.epizy.com/` (or your subfolder URL).
3. Open **`auth/login.php`** (full URL depends on `DRAS_WEB_BASE`; e.g. `https://yoursite.epizy.com/auth/login.php` when base is `''`).
4. Log in with seeded accounts from **`sql/demo_credentials.txt`** (change passwords after testing).

### Common issues (InfinityFree)

| Problem | What to check |
|--------|----------------|
| CSS/JS 404, links go to wrong path | `DRAS_WEB_BASE` in `config.local.php` must match how the site is served (`''` vs `/subfolder`). |
| Database connection error | Host must be the **remote** host from the panel, not `localhost`. User/password/database names must match exactly (including `epiz_` prefix). |
| Blank page | Enable error logging or temporarily set `display_errors` in a test file; check PHP version ≥ 7.4. |
| Sessions / login not sticking | HTTPS mixed content, or cookie path — try same URL scheme (always `https://`). |
| Import fails | Remove `CREATE DATABASE` / use single database name assigned by InfinityFree. |

---

## Project layout (after reorganization)

| Path | Role |
|------|------|
| `index.php` | Landing page |
| `auth/` | Login, register, logout |
| `student/` | Student dashboard, results, transcript |
| `lecturer/` | Dashboard, result upload, course score limits |
| `admin/` | Approvals, courses, users, master data |
| `includes/` | Config, DB, CSRF, helpers |
| `assets/css/style.css` | Main stylesheet (`style.css` at root re-exports it) |
| `uploads/receipts/` | Transcript receipt files |
| `sql/install_full.sql` | Full schema + seed data |

---

## Security reminders for production

- Change all **demo** and **admin** passwords after deployment.
- Keep **`includes/config.local.php`** private.
- Restrict **`uploads/`** so PHP cannot be executed from there (InfinityFree often serves static files only — follow their docs).

---

## Support

InfinityFree community: [forum.infinityfree.net](https://forum.infinityfree.net).  
App path and DB settings are controlled by **`includes/config.php`** and **`includes/config.local.php`**.
