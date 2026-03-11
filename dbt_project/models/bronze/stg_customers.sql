-- Bronze: raw customers

{{ config(materialized='view') }}

select
    customer_id::varchar        as customer_id,
    customer_name::varchar      as customer_name,
    email::varchar              as email,
    country::varchar            as country,
    city::varchar               as city,
    customer_segment::varchar   as customer_segment,
    signup_date::date           as signup_date,
    is_active::boolean          as is_active,
    account_manager::varchar    as account_manager,
    _loaded_at::timestamp       as _loaded_at
from {{ source('raw', 'customers') }}
