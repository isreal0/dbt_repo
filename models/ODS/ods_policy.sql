{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge',
        on_schema_change='fail'
    )
}}

select
    order_id,
    customer_name,
    product_name,
    amount,
    order_date,
    current_timestamp as dbt_loaded_at,
    'redshift_datashare'::varchar(50) as dbt_source_system

from {{ ref('stg_policy') }}