# Deploying Airflow on AWS EC2

This guide documents how to deploy the Enterprise Analytics Airflow scheduler
on an EC2 instance — the same setup used in the Cognizant production environment.

## Infrastructure

| Component | Spec |
|---|---|
| Instance type | t3.medium (2 vCPU, 4GB RAM) |
| OS | Ubuntu 22.04 LTS |
| Airflow version | 2.9.2 |
| Executor | LocalExecutor (single-node) |
| Metadata DB | PostgreSQL 15 (RDS or local) |
| Region | us-west-2 |

## Architecture

```
AWS EC2 (t3.medium)
├── Airflow Webserver  :8080
├── Airflow Scheduler
└── dbt (runs inside scheduler via BashOperator)
         │
         ▼
Snowflake (ANALYTICS_DB)
         │
         ▼
Slack Webhook → #data-alerts
```

## Prerequisites

- EC2 instance running Ubuntu 22.04
- Security group: inbound 22 (SSH), 8080 (Airflow UI)
- IAM role with S3 read access (for external stage)
- RDS PostgreSQL instance OR local Postgres

## Setup

Run `scripts/bootstrap_ec2.sh` on a fresh EC2 instance:

```bash
# SSH into your instance
ssh -i your-key.pem ubuntu@<ec2-public-ip>

# Clone the repo
git clone https://github.com/kiranmayee2408/enterprise-analytics-platform.git
cd enterprise-analytics-platform

# Run bootstrap
chmod +x scripts/bootstrap_ec2.sh
./scripts/bootstrap_ec2.sh
```

## Environment Variables

Set these in `/etc/environment` on the EC2 instance:

```bash
SNOWFLAKE_ACCOUNT=your_account.us-east-1
SNOWFLAKE_USER=dbt_user
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_ROLE=dbt_role
SNOWFLAKE_WAREHOUSE=ETL_WH
SNOWFLAKE_DATABASE=ANALYTICS_DB
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK
AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow:airflow@localhost/airflow
```

## SLA Configuration

The DAG enforces a 2-hour SLA on the full pipeline:

```python
"sla": timedelta(hours=2)
```

If the pipeline hasn't completed within 2 hours of its 6 AM schedule,
Airflow fires `check_sla_miss()` which sends a Slack alert to `#data-alerts`.

## Monitoring

- **Airflow UI:** `http://<ec2-ip>:8080` (admin/admin by default — change in production)
- **Scheduler logs:** `/opt/airflow/logs/scheduler/`
- **dbt logs:** `/opt/airflow/dbt_project/logs/`

## Cost Estimate

| Resource | Monthly Cost |
|---|---|
| EC2 t3.medium | ~$30 |
| RDS db.t3.micro (Postgres) | ~$15 |
| Data transfer | ~$2 |
| **Total** | **~$47/month** |

For a small team running daily refreshes, a single t3.medium handles the load
comfortably. Scale to t3.large if Silver incremental merges exceed 30 minutes.
