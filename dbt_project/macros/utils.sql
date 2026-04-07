{% macro safe_divide(numerator, denominator) %}
    case when {{ denominator }} = 0 or {{ denominator }} is null
         then null
         else {{ numerator }}::float / {{ denominator }}
    end
{% endmacro %}


{% macro date_spine(start_date, end_date, datepart='day') %}
    with date_spine as (
        select dateadd({{ datepart }}, seq4(), '{{ start_date }}'::date) as date_day
        from table(generator(rowcount => 3650))
    )
    select date_day
    from date_spine
    where date_day between '{{ start_date }}' and '{{ end_date }}'
{% endmacro %}


{% macro dq_not_null_pct(column_name, threshold=0.99) %}
    -- Assert that at least {threshold}% of rows have non-null values
    select
        count_if({{ column_name }} is null)::float / nullif(count(*), 0) as null_pct
    from {{ this }}
    having null_pct > {{ 1 - threshold }}
{% endmacro %}


{% macro freshness_check(timestamp_column, max_hours=25) %}
    -- Assert that data is fresh (updated within max_hours)
    select datediff('hour', max({{ timestamp_column }}), current_timestamp()) as hours_stale
    from {{ this }}
    having hours_stale > {{ max_hours }}
{% endmacro %}


{% macro revenue_bands(revenue_column) %}
    case
        when {{ revenue_column }} < 1000    then '< $1K'
        when {{ revenue_column }} < 10000   then '$1K–$10K'
        when {{ revenue_column }} < 100000  then '$10K–$100K'
        else '> $100K'
    end
{% endmacro %}


{% macro generate_surrogate_key(fields) %}
    md5(
        cast(coalesce(
            {%- for field in fields %}
            cast({{ field }} as varchar)
            {%- if not loop.last %} || '|' || {% endif %}
            {%- endfor %}
        , '') as varchar)
    )
{% endmacro %}
