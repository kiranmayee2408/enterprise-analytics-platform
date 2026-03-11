-- Bronze: raw orders from source system
-- Materialized as view — no transformation, just a clean reference to raw data

{{ config(materialized='view') }}

with source as (
    select * from {{ source('raw', 'orders') }}
),

typed as (
    select
        order_id::varchar          as order_id,
        customer_id::varchar       as customer_id,
        product_id::varchar        as product_id,
        order_date::date           as order_date,
        shipped_date::date         as shipped_date,
        quantity::int              as quantity,
        unit_price::decimal(10,2)  as unit_price,
        discount_pct::decimal(5,2) as discount_pct,
        status::varchar            as status,
        region::varchar            as region,
        channel::varchar           as channel,

        -- Audit columns
        _loaded_at::timestamp      as _loaded_at,
        _source_file::varchar      as _source_file

    from source
)

select * from typed
