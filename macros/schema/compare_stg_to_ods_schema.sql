{% test compare_stg_to_ods_schema(model) %}

{% set stg_database = model.database %}
{% set stg_schema = model.schema %}
{% set stg_table = model.identifier %}
{% set ods_database = model.database %}
{% set ods_schema = model.schema %}
{% set ods_table = model.identifier | replace('stg_', 'ods_') %}

{{ schema_diff_sql(
    stg_database,
    stg_schema,
    stg_table,
    ods_database,
    ods_schema,
    ods_table
) }}

{% endtest %}