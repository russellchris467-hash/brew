"""
Hackable Raspberry Pi Simulator - Cybersecurity Training Target
================================================================
WARNING: This application is INTENTIONALLY VULNERABLE.
DO NOT deploy this in a production environment or on a public network.
For use in isolated lab/CTF environments ONLY.

Vulnerabilities included (for training purposes):
  [VULN-01] SQL Injection        - /login endpoint
  [VULN-02] Stored XSS           - /dashboard notes feature
  [VULN-03] Command Injection    - /terminal ping utility
  [VULN-04] Weak Credentials     - default admin/raspberry
  [VULN-05] IDOR                 - /api/user/<id> exposes any user
  [VULN-06] Path Traversal       - /files endpoint
  [VULN-07] Broken Access Control- /admin panel
  [VULN-08] Hardcoded Secret Key - Flask secret key in source
  [VULN-09] Verbose Error Pages  - raw exceptions exposed
  [VULN-10] Information Leakage  - /api/info endpoint

Flags hidden throughout for CTF challenges:
  FLAG{sql_1nj3ct10n_byp4ss}
  FLAG{xss_st0r3d_4tt4ck}
  FLAG{c0mm4nd_1nj3ct10n}
  FLAG{1d0r_us3r_3xp0s3d}
  FLAG{p4th_tr4v3rs4l}
  FLAG{4dm1n_p4n3l_byp4ss}
"""

import os
import sqlite3
import subprocess
from flask import (Flask, request, render_template, redirect,
                   url_for, session, jsonify, make_response)

# [VULN-08] Hardcoded, weak secret key
app = Flask(__name__)
app.secret_key = "raspberry"

DB_PATH = os.path.join(os.path.dirname(__file__), "db", "rpi.db")
FILES_DIR = os.path.join(os.path.dirname(__file__), "files")


# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    os.makedirs(FILES_DIR, exist_ok=True)

    conn = get_db()
    cur = conn.cursor()

    cur.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            role     TEXT DEFAULT 'user',
            email    TEXT
        );

        CREATE TABLE IF NOT EXISTS notes (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            title   TEXT,
            content TEXT
        );

        CREATE TABLE IF NOT EXISTS gpio_pins (
            pin    INTEGER PRIMARY KEY,
            label  TEXT,
            state  TEXT DEFAULT 'LOW'
        );

        CREATE TABLE IF NOT EXISTS secrets (
            id    INTEGER PRIMARY KEY AUTOINCREMENT,
            name  TEXT,
            value TEXT
        );
    """)

    # Seed users — [VULN-04] default credentials: admin/raspberry
    cur.execute("SELECT COUNT(*) FROM users")
    if cur.fetchone()[0] == 0:
        cur.executescript("""
            INSERT INTO users (username, password, role, email) VALUES
                ('admin',   'raspberry',  'admin', 'admin@rpi.local'),
                ('pi',      'pi',         'user',  'pi@rpi.local'),
                ('alice',   'alice123',   'user',  'alice@rpi.local'),
                ('bob',     'password1',  'user',  'bob@rpi.local');
        """)

    # Seed GPIO pins
    cur.execute("SELECT COUNT(*) FROM gpio_pins")
    if cur.fetchone()[0] == 0:
        cur.executescript("""
            INSERT INTO gpio_pins (pin, label, state) VALUES
                (2,  'LED Red',    'LOW'),
                (3,  'LED Green',  'HIGH'),
                (4,  'Sensor DHT', 'LOW'),
                (17, 'Relay 1',    'LOW'),
                (27, 'Relay 2',    'LOW'),
                (22, 'Buzzer',     'LOW');
        """)

    # Hidden CTF secrets table
    cur.execute("SELECT COUNT(*) FROM secrets")
    if cur.fetchone()[0] == 0:
        cur.executescript("""
            INSERT INTO secrets (name, value) VALUES
                ('sql_flag',     'FLAG{sql_1nj3ct10n_byp4ss}'),
                ('admin_flag',   'FLAG{4dm1n_p4n3l_byp4ss}'),
                ('api_key',      'sk-rpi-prod-4a8f2c91e3b7'),
                ('wifi_pass',    'HomeNetwork2024!'),
                ('db_backup',    'See /files/backup.txt');
        """)

    # Seed a stored XSS note
    cur.execute("SELECT COUNT(*) FROM notes")
    if cur.fetchone()[0] == 0:
        cur.executescript("""
            INSERT INTO notes (user_id, title, content) VALUES
                (1, 'Welcome',          'Welcome to your Raspberry Pi dashboard!'),
                (1, 'GPIO Setup',       'GPIO 17 connected to relay board.'),
                (2, 'My note',          'Remember to update firmware.');
        """)

    conn.commit()
    conn.close()

    # Create sample files for path traversal
    os.makedirs(FILES_DIR, exist_ok=True)
    with open(os.path.join(FILES_DIR, "readme.txt"), "w") as f:
        f.write("Raspberry Pi project files\nSee backup.txt for credentials.\n")
    with open(os.path.join(FILES_DIR, "backup.txt"), "w") as f:
        f.write("=== BACKUP CREDENTIALS ===\nSSH user: pi\nSSH pass: raspberry\nFlag: FLAG{p4th_tr4v3rs4l}\n")
    with open(os.path.join(FILES_DIR, "gpio_config.txt"), "w") as f:
        f.write("GPIO 17 -> Relay\nGPIO 27 -> Fan\nGPIO 22 -> Buzzer\n")


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.route("/")
def index():
    return redirect(url_for("login"))


@app.route("/login", methods=["GET", "POST"])
def login():
    error = None
    if request.method == "POST":
        username = request.form.get("username", "")
        password = request.form.get("password", "")

        # [VULN-01] SQL Injection — query built with string formatting
        query = (
            f"SELECT * FROM users WHERE username = '{username}' "
            f"AND password = '{password}'"
        )
        try:
            conn = get_db()
            # [VULN-09] Raw exception exposed to user on error
            user = conn.execute(query).fetchone()
            conn.close()
        except Exception as e:
            return f"<pre>Database error: {e}\nQuery: {query}</pre>", 500

        if user:
            session["user_id"]  = user["id"]
            session["username"] = user["username"]
            session["role"]     = user["role"]
            return redirect(url_for("dashboard"))
        else:
            error = "Invalid credentials."

    return render_template("login.html", error=error)


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


@app.route("/dashboard", methods=["GET", "POST"])
def dashboard():
    if "user_id" not in session:
        return redirect(url_for("login"))

    conn = get_db()
    msg = None

    if request.method == "POST":
        title   = request.form.get("title", "")
        content = request.form.get("content", "")
        # [VULN-02] Stored XSS — content is NOT sanitised before storage
        conn.execute(
            "INSERT INTO notes (user_id, title, content) VALUES (?, ?, ?)",
            (session["user_id"], title, content),
        )
        conn.commit()
        msg = "Note saved."

    # Fetch notes for this user
    notes = conn.execute(
        "SELECT * FROM notes WHERE user_id = ?", (session["user_id"],)
    ).fetchall()
    pins = conn.execute("SELECT * FROM gpio_pins").fetchall()
    conn.close()

    return render_template(
        "dashboard.html",
        notes=notes,
        pins=pins,
        msg=msg,
        username=session["username"],
        role=session["role"],
    )


@app.route("/terminal", methods=["GET", "POST"])
def terminal():
    if "user_id" not in session:
        return redirect(url_for("login"))

    output = None
    if request.method == "POST":
        host = request.form.get("host", "")
        # [VULN-03] Command Injection — host is passed directly to shell
        cmd = f"ping -c 2 {host}"
        try:
            output = subprocess.check_output(
                cmd, shell=True, stderr=subprocess.STDOUT, timeout=10
            ).decode()
        except subprocess.TimeoutExpired:
            output = "Request timed out."
        except subprocess.CalledProcessError as e:
            output = e.output.decode()

    return render_template("terminal.html", output=output,
                           username=session["username"])


@app.route("/files")
def files():
    if "user_id" not in session:
        return redirect(url_for("login"))

    # [VULN-06] Path Traversal — filename from query string used directly
    filename = request.args.get("name", "")
    if filename:
        # Vulnerable: no path normalisation
        filepath = os.path.join(FILES_DIR, filename)
        try:
            with open(filepath, "r") as f:
                content = f.read()
        except Exception as e:
            content = f"Error: {e}"
        return render_template("files.html", filename=filename,
                               content=content, username=session["username"])

    # List available files
    try:
        file_list = os.listdir(FILES_DIR)
    except Exception:
        file_list = []
    return render_template("files.html", file_list=file_list, content=None,
                           username=session["username"])


@app.route("/admin")
def admin():
    # [VULN-07] Broken Access Control — only checks a query param, not session role
    if request.args.get("auth") == "1":
        conn = get_db()
        users   = conn.execute("SELECT * FROM users").fetchall()
        secrets = conn.execute("SELECT * FROM secrets").fetchall()
        conn.close()
        return render_template("admin.html", users=users, secrets=secrets,
                               username=session.get("username", "anonymous"))
    return render_template("admin_denied.html"), 403


@app.route("/gpio/toggle", methods=["POST"])
def gpio_toggle():
    if "user_id" not in session:
        return jsonify({"error": "Unauthorized"}), 401
    pin = request.form.get("pin")
    conn = get_db()
    current = conn.execute(
        "SELECT state FROM gpio_pins WHERE pin = ?", (pin,)
    ).fetchone()
    if current:
        new_state = "LOW" if current["state"] == "HIGH" else "HIGH"
        conn.execute(
            "UPDATE gpio_pins SET state = ? WHERE pin = ?", (new_state, pin)
        )
        conn.commit()
    conn.close()
    return redirect(url_for("dashboard"))


# ---------------------------------------------------------------------------
# API endpoints
# ---------------------------------------------------------------------------

@app.route("/api/info")
def api_info():
    # [VULN-10] Information leakage — exposes OS info, paths, Python version
    import platform, sys
    return jsonify({
        "device":      "Raspberry Pi 4 Model B (simulated)",
        "hostname":    "raspberrypi",
        "os":          platform.platform(),
        "python":      sys.version,
        "db_path":     DB_PATH,
        "files_dir":   FILES_DIR,
        "server_root": os.path.abspath(os.path.dirname(__file__)),
        "hint":        "Try /admin?auth=1 or inject some SQL in /login",
    })


@app.route("/api/user/<int:user_id>")
def api_user(user_id):
    # [VULN-05] IDOR — any authenticated (or unauthenticated) caller can
    # enumerate users by changing the id parameter
    conn = get_db()
    user = conn.execute(
        "SELECT id, username, role, email FROM users WHERE id = ?", (user_id,)
    ).fetchone()
    conn.close()
    if user:
        flag = "FLAG{1d0r_us3r_3xp0s3d}" if user_id != session.get("user_id") else ""
        return jsonify({
            "id":       user["id"],
            "username": user["username"],
            "role":     user["role"],
            "email":    user["email"],
            "flag":     flag,
        })
    return jsonify({"error": "User not found"}), 404


@app.route("/api/gpio")
def api_gpio():
    if "user_id" not in session:
        return jsonify({"error": "Unauthorized"}), 401
    conn = get_db()
    pins = conn.execute("SELECT * FROM gpio_pins").fetchall()
    conn.close()
    return jsonify([dict(p) for p in pins])


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    init_db()
    print("\n" + "=" * 60)
    print("  Hackable Raspberry Pi Simulator — TRAINING USE ONLY")
    print("=" * 60)
    print("  URL      : http://127.0.0.1:5000")
    print("  Username : admin   Password: raspberry")
    print("  Username : pi      Password: pi")
    print("=" * 60)
    print("  10 vulnerabilities planted — can you find them all?")
    print("=" * 60 + "\n")
    # [VULN-09] debug=True exposes interactive debugger
    app.run(host="0.0.0.0", port=5000, debug=True)
