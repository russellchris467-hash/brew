FROM python:3.11-slim

LABEL description="Hackable Raspberry Pi Simulator — Cybersecurity Training Target"
LABEL warning="INTENTIONALLY VULNERABLE — Do not expose to public networks"

WORKDIR /app

# Install system deps for ping (used by VULN-03 command injection demo)
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      iputils-ping \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Create required directories
RUN mkdir -p db files

EXPOSE 5000

# Initialise DB then launch app
CMD python -c "from app import init_db; init_db()" && \
    python app.py
