-- Gold: Customer 360 — one row per customer with lifetime metrics
-- Powers customer health scoring and churn dashboards

{{ config(materialized='table', cluster_by=['customer_segment', 'country']) }}

with orders as (
    select * from {{ ref('int_orders_enriched') }}
),

customer_base as (
    select * from {{ ref('stg_customers') }}
),

customer_metrics as (
    select
        customer_id,

        -- Activity
        min(order_date)                            as first_order_date,
        max(order_date)                            as last_order_date,
        datediff('day', min(order_date), max(order_date)) as customer_tenure_days,
        count(distinct order_id)                   as lifetime_order_count,
        count(distinct date_trunc('month', order_date)) as active_months,

        -- Revenue
        sum(gross_revenue)                         as lifetime_gross_revenue,
        sum(net_revenue)                           as lifetime_net_revenue,
        avg(net_revenue)                           as avg_order_value,
        max(net_revenue)                           as max_single_order,
        sum(discount_amount)                       as total_discounts_received,

        -- Recency (days since last order — lower is better for retention)
        datediff('day', max(order_date), current_date()) as days_since_last_order,

        -- Fulfilment experience
        avg(days_to_ship)                          as avg_days_to_ship,
        sum(case when shipped_on_time then 1 else 0 end)::float
            / nullif(count(*), 0) * 100            as pct_orders_on_time

    from orders
    group by 1
),

rfm as (
    -- RFM segmentation for targeting
    select
        customer_id,
        ntile(5) over (order by days_since_last_order asc)  as recency_score,  -- 5 = most recent
        ntile(5) over (order by lifetime_order_count asc)   as frequency_score,
        ntile(5) over (order by lifetime_net_revenue asc)   as monetary_score
    from customer_metrics
),

final as (
    select
        cb.customer_id,
        cb.customer_name,
        cb.email,
        cb.customer_segment,
        cb.country,
        cb.city,
        cb.signup_date,
        cb.account_manager,
        cb.is_active,

        cm.*,

        rfm.recency_score,
        rfm.frequency_score,
        rfm.monetary_score,
        rfm.recency_score + rfm.frequency_score + rfm.monetary_score as rfm_total,

        -- Churn risk heuristic
        case
            when cm.days_since_last_order > 180 then 'high'
            when cm.days_since_last_order > 90  then 'medium'
            else 'low'
        end as churn_risk,

        -- Customer tier
        case
            when cm.lifetime_net_revenue > 100000 then 'Platinum'
            when cm.lifetime_net_revenue > 25000  then 'Gold'
            when cm.lifetime_net_revenue > 5000   then 'Silver'
            else 'Bronze'
        end as customer_tier,

        current_timestamp() as _refreshed_at

    from customer_base cb
    left join customer_metrics cm using (customer_id)
    left join rfm using (customer_id)
)

select * from final
