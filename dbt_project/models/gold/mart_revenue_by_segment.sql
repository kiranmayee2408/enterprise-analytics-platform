-- Gold: Monthly revenue by customer segment
-- Used directly by Tableau/PowerBI executive dashboards

{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('int_orders_enriched') }}
    where order_date >= '{{ var("start_date") }}'
),

monthly_segment as (
    select
        order_month,
        order_year,
        customer_segment,
        region,
        channel,

        -- Volume
        count(distinct order_id)          as order_count,
        count(distinct customer_id)       as unique_customers,
        sum(quantity)                     as total_units,

        -- Revenue
        sum(gross_revenue)                as gross_revenue,
        sum(net_revenue)                  as net_revenue,
        sum(discount_amount)              as total_discounts,
        avg(net_revenue)                  as avg_order_value,

        -- Fulfilment
        avg(days_to_ship)                 as avg_days_to_ship,
        sum(case when shipped_on_time then 1 else 0 end)::float
            / nullif(count(*), 0) * 100  as on_time_delivery_pct

    from orders
    group by 1, 2, 3, 4, 5
),

with_mom_growth as (
    select
        *,
        lag(net_revenue) over (
            partition by customer_segment, region, channel
            order by order_month
        )                                                  as prev_month_revenue,

        net_revenue - lag(net_revenue) over (
            partition by customer_segment, region, channel
            order by order_month
        )                                                  as revenue_mom_delta,

        (net_revenue - lag(net_revenue) over (
            partition by customer_segment, region, channel
            order by order_month
        )) / nullif(lag(net_revenue) over (
            partition by customer_segment, region, channel
            order by order_month
        ), 0) * 100                                        as revenue_mom_growth_pct

    from monthly_segment
)

select * from with_mom_growth
order by order_month desc, net_revenue desc
