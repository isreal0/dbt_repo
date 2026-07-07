{{ config(materialized='table') }}

select
    order_id,
    customer_name,
    product_name,
    amount,
    order_date,

    current_timestamp as dbt_loaded_at,
    'demo_datashare.policy' as dbt_source_system

from {{ source('demo_datashare', 'policy') }}