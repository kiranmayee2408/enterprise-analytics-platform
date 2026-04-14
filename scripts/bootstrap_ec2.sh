#!/bin/bash
# bootstrap_ec2.sh
# Installs Airflow + dbt on a fresh Ubuntu 22.04 EC2 instance
# Run as: chmod +x scripts/bootstrap_ec2.sh && ./scripts/bootstrap_ec2.sh

set -e
echo "=== Enterprise Analytics Platform — EC2 Bootstrap ==="
echo "Starting setup on $(hostname) at $(date)"

# ── System packages ──────────────────────────────────────────────────────────
echo "[1/7] Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
  python3.11 python3.11-venv python3-pip \
  git curl wget unzip \
  postgresql-client \
  build-essential libssl-dev libffi-dev

# ── Python virtual environment ───────────────────────────────────────────────
echo "[2/7] Creating Python virtual environment..."
python3.11 -m venv /opt/analytics-venv
source /opt/analytics-venv/bin/activate

# ── Airflow ──────────────────────────────────────────────────────────────────
echo "[3/7] Installing Apache Airflow 2.9.2..."
pip install --quiet --upgrade pip
pip install --quiet \
  "apache-airflow==2.9.2" \
  "apache-airflow-providers-slack==8.8.0" \
  "apache-airflow-providers-snowflake==5.8.0"

# ── dbt ──────────────────────────────────────────────────────────────────────
echo "[4/7] Installing dbt-snowflake..."
pip install --quiet dbt-snowflake==1.8.4

# ── Airflow database init ────────────────────────────────────────────────────
echo "[5/7] Initialising Airflow metadata database..."
export AIRFLOW_HOME=/opt/airflow
airflow db migrate

# Create admin user (change password before production use)
airflow users create \
  --username admin \
  --password admin123 \
  --firstname Kiranmayee \
  --lastname Lokam \
  --role Admin \
  --email kiranmayeelokam8@gmail.com \
  2>/dev/null || echo "User already exists — skipping"

# ── Copy DAGs and dbt project ────────────────────────────────────────────────
echo "[6/7] Copying DAGs and dbt project..."
mkdir -p /opt/airflow/dags
cp -r airflow/dags/* /opt/airflow/dags/
cp -r dbt_project /opt/airflow/dbt_project
mkdir -p /opt/airflow/.dbt
cp config/profiles.yml.example /opt/airflow/.dbt/profiles.yml
echo "⚠️  Edit /opt/airflow/.dbt/profiles.yml with your Snowflake credentials"

# ── Systemd services ─────────────────────────────────────────────────────────
echo "[7/7] Creating systemd services..."

sudo tee /etc/systemd/system/airflow-webserver.service > /dev/null << 'SERVICE'
[Unit]
Description=Airflow Webserver
After=network.target

[Service]
User=ubuntu
Environment=AIRFLOW_HOME=/opt/airflow
ExecStart=/opt/analytics-venv/bin/airflow webserver --port 8080
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

sudo tee /etc/systemd/system/airflow-scheduler.service > /dev/null << 'SERVICE'
[Unit]
Description=Airflow Scheduler
After=network.target

[Service]
User=ubuntu
Environment=AIRFLOW_HOME=/opt/airflow
ExecStart=/opt/analytics-venv/bin/airflow scheduler
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable airflow-webserver airflow-scheduler
sudo systemctl start airflow-webserver airflow-scheduler

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "=== Bootstrap complete ==="
echo "Airflow UI: http://$(curl -s ifconfig.me):8080"
echo "Username: admin | Password: admin123"
echo ""
echo "Next steps:"
echo "  1. Edit /opt/airflow/.dbt/profiles.yml with Snowflake credentials"
echo "  2. Set SLACK_WEBHOOK_URL in /etc/environment"
echo "  3. Restart scheduler: sudo systemctl restart airflow-scheduler"
echo "  4. Enable the DAG in the Airflow UI"
