-- Silver: cleaned and enriched orders
-- Incremental merge — only processes new/changed records

{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge',
        cluster_by=['order_date', 'region']
    )
}}

with orders as (
    select * from {{ ref('stg_orders') }}
    {% if is_incremental() %}
        where _loaded_at > (select max(_loaded_at) from {{ this }})
    {% endif %}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

enriched as (
    select
        o.order_id,
        o.customer_id,
        o.product_id,
        o.order_date,
        o.shipped_date,
        o.quantity,
        o.unit_price,
        o.discount_pct,
        o.status,
        o.region,
        o.channel,

        -- Calculated revenue metrics
        o.quantity * o.unit_price                              as gross_revenue,
        o.quantity * o.unit_price * (1 - o.discount_pct / 100) as net_revenue,
        o.quantity * o.unit_price * o.discount_pct / 100       as discount_amount,

        -- Fulfilment
        datediff('day', o.order_date, o.shipped_date)          as days_to_ship,
        case when o.shipped_date <= o.order_date + 2 then true
             else false end                                     as shipped_on_time,

        -- Customer enrichment
        c.customer_name,
        c.customer_segment,
        c.country,
        c.city,
        c.account_manager,

        -- Date dimensions
        date_trunc('month', o.order_date)  as order_month,
        date_trunc('quarter', o.order_date) as order_quarter,
        extract(year from o.order_date)    as order_year,
        dayofweek(o.order_date)            as order_dow,

        -- Data quality
        case when o.unit_price <= 0 then 'invalid_price'
             when o.quantity <= 0   then 'invalid_quantity'
             when o.customer_id is null then 'missing_customer'
             else 'ok' end                                     as dq_flag,

        o._loaded_at,
        current_timestamp()                                    as _transformed_at

    from orders o
    left join customers c using (customer_id)
)

select * from enriched
where dq_flag = 'ok'  -- only clean records flow to silver
