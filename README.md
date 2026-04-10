# Enterprise Analytics Platform

A production-grade **data warehouse** built on Snowflake + dbt + Airflow — delivering daily-refreshed analytics marts to Tableau dashboards, with 50+ automated data quality tests and lineage tracking.

![dbt](https://img.shields.io/badge/dbt-1.8-orange?logo=dbt)
![Snowflake](https://img.shields.io/badge/Snowflake-enterprise-blue?logo=snowflake)
![Airflow](https://img.shields.io/badge/Airflow-2.9-red?logo=apacheairflow)
![Tests](https://img.shields.io/badge/dbt_tests-50%2B-green)

---

## Business Impact

This platform replaced 15+ manual Power BI data pulls and reduced analyst query turnaround from **3 days to under 5 minutes**. Automated SLA monitoring and Slack alerting catch pipeline issues before analysts notice.

---

## Architecture

```
Source Systems (ERP, CRM)
         │  AWS DMS / Fivetran
         ▼
┌────────────────────────┐
│   RAW schema           │  Immutable raw tables — never modified
│   (Snowflake)          │  Freshness checked before each run
└──────────┬─────────────┘
           │ dbt (Bronze)
           ▼
┌────────────────────────┐
│   BRONZE schema        │  Type casting, schema enforcement
│   Views                │  No business logic
└──────────┬─────────────┘
           │ dbt (Silver)
           ▼
┌────────────────────────┐
│   SILVER schema        │  Incremental merge, feature engineering,
│   Incremental tables   │  DQ filtering, customer enrichment
└──────────┬─────────────┘
           │ dbt (Gold)
           ▼
┌────────────────────────┐
│   GOLD schema          │  Revenue marts, Customer 360, RFM scores
│   Tables (clustered)   │  Directly consumed by BI tools
└──────────┬─────────────┘
           │
    ┌──────┴──────┐
    ▼             ▼
 Tableau       Power BI
 Dashboards    Dashboards
```

**Orchestration:**
```
Airflow (6 AM daily)
  → Source freshness check
  → dbt run + test (Bronze)
  → dbt run + test (Silver)
  → dbt run + test (Gold)
  → Row count validation
  → Slack alert (success/failure)
```

---

## Quickstart

```bash
git clone https://github.com/kiranmayee2408/enterprise-analytics-platform.git
cd enterprise-analytics-platform

# Install dbt
pip install dbt-snowflake==1.8.0

# Configure Snowflake connection
cp config/profiles.yml.example ~/.dbt/profiles.yml
# Edit with your Snowflake credentials

# Run the full pipeline
cd dbt_project
dbt deps
dbt source freshness     # Check raw data is fresh
dbt run                  # Build all models
dbt test                 # Run 50+ data quality checks
dbt docs generate && dbt docs serve  # Interactive lineage + docs
```

---

## dbt Models

### Bronze (Views) — Raw validation
| Model | Description |
|---|---|
| `stg_orders` | Typed orders from ERP — schema validation and casting |
| `stg_customers` | Customer master with segment classification |

### Silver (Incremental) — Feature engineering
| Model | Description |
|---|---|
| `int_orders_enriched` | Orders + customer join, revenue calculations, DQ filter, on-time shipping |

### Gold (Tables) — Business marts
| Model | Description | Consumers |
|---|---|---|
| `mart_revenue_by_segment` | Monthly revenue, MoM growth by segment/region/channel | Executive dashboard |
| `mart_customer_360` | Lifetime value, RFM scores, churn risk, customer tier | CRM, retention |

---

## Data Quality

50+ automated tests run after every pipeline execution:

| Test Type | Example |
|---|---|
| Uniqueness | `order_id`, `customer_id`, `email` must be unique |
| Not null | All key columns validated |
| Accepted values | `status` in ['pending', 'confirmed', 'shipped', ...] |
| Range checks | `unit_price` between 0 and 1M, `discount_pct` between 0 and 100 |
| Referential integrity | Every order has a valid customer |
| Freshness | Source tables updated within 24 hours |
| Business rules | Silver layer contains only `dq_flag = 'ok'` records |

---

## Macros

| Macro | Description |
|---|---|
| `safe_divide` | Null-safe division for ratio calculations |
| `date_spine` | Generate a complete date series |
| `revenue_bands` | Consistent revenue bucketing |
| `generate_surrogate_key` | MD5-based surrogate keys from natural keys |
| `freshness_check` | Assert data is no older than N hours |

---

## Airflow DAG

Daily run at 6 AM UTC with 2-hour SLA.

Features:
- Layer-by-layer execution (Bronze → Silver → Gold) with test gates between each layer
- Slack alerting on success and failure
- SLA miss callback
- Automatic dbt docs regeneration after each successful run
- Email alerting on failure with retry logic

---

## Tech Stack

| Component | Technology |
|---|---|
| Data warehouse | Snowflake |
| Transformation | dbt Core 1.8 |
| Orchestration | Apache Airflow 2.9 |
| BI | Tableau, Power BI |
| CI/CD | GitHub Actions (dbt run on PR) |
| Alerting | Slack webhooks |

---

## Project Structure

```
enterprise-analytics/
├── dbt_project/
│   ├── models/
│   │   ├── bronze/               # stg_orders, stg_customers (views)
│   │   ├── silver/               # int_orders_enriched (incremental)
│   │   └── gold/                 # mart_revenue_by_segment, mart_customer_360
│   ├── macros/utils.sql          # 6 reusable SQL macros
│   ├── tests/schema.yml          # 50+ data quality tests
│   └── dbt_project.yml           # Project config + materialization strategy
├── airflow/
│   └── dags/analytics_pipeline.py  # Full orchestration DAG with SLA
└── config/                       # dbt profiles, environment config
```

---

## Related Work

- [Streaming ML Pipeline](https://github.com/kiranmayee2408/streaming-ml-pipeline) — Real-time counterpart using Kafka + PySpark
- [LLM Observability Dashboard](https://github.com/kiranmayee2408/llm-observability-dashboard) — Same engineering principles applied to AI systems

---

## License

MIT
