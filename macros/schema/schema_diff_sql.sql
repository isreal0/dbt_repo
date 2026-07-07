{% macro schema_diff_sql(stg_database, stg_schema, stg_table, ods_database, ods_schema, ods_table) %}

with stg_cols as (

    select
        lower(column_name) as column_name,
        lower(data_type) as data_type,
        ordinal_position
    from svv_all_columns
    where database_name = '{{ stg_database }}'
      and schema_name = '{{ stg_schema }}'
      and table_name = '{{ stg_table }}'
      and lower(column_name) not like 'dbt%'

),

ods_cols as (

    select
        lower(column_name) as column_name,
        lower(data_type) as data_type,
        ordinal_position
    from svv_all_columns
    where database_name = '{{ ods_database }}'
      and schema_name = '{{ ods_schema }}'
      and table_name = '{{ ods_table }}'
      and lower(column_name) not like 'dbt%'

),

missing_in_ods as (

    select
        'MISSING_IN_ODS' as change_type,
        s.column_name,
        s.data_type as staging_data_type,
        cast(null as varchar(256)) as ods_data_type,
        s.ordinal_position as staging_ordinal_position,
        cast(null as integer) as ods_ordinal_position
    from stg_cols s
    left join ods_cols o
        on s.column_name = o.column_name
    where o.column_name is null

),

extra_in_ods as (

    select
        'EXTRA_IN_ODS' as change_type,
        o.column_name,
        cast(null as varchar(256)) as staging_data_type,
        o.data_type as ods_data_type,
        cast(null as integer) as staging_ordinal_position,
        o.ordinal_position as ods_ordinal_position
    from ods_cols o
    left join stg_cols s
        on o.column_name = s.column_name
    where s.column_name is null

),

type_changed as (

    select
        'DATA_TYPE_CHANGED' as change_type,
        s.column_name,
        s.data_type as staging_data_type,
        o.data_type as ods_data_type,
        s.ordinal_position as staging_ordinal_position,
        o.ordinal_position as ods_ordinal_position
    from stg_cols s
    join ods_cols o
        on s.column_name = o.column_name
    where s.data_type <> o.data_type

),

all_issues as (

    select * from missing_in_ods
    union all
    select * from extra_in_ods
    union all
    select * from type_changed

)

select
    current_timestamp as checked_at,
    '{{ stg_database }}.{{ stg_schema }}.{{ stg_table }}' as staging_relation,
    '{{ ods_database }}.{{ ods_schema }}.{{ ods_table }}' as ods_relation,
    change_type,
    column_name,
    staging_data_type,
    ods_data_type,
    staging_ordinal_position,
    ods_ordinal_position,
    case
        when change_type = 'DATA_TYPE_CHANGED' then
            'DATA_TYPE_CHANGED: column '
            || column_name
            || ' type mismatch between staging and ods. staging='
            || coalesce(staging_data_type, 'NULL')
            || ', ods='
            || coalesce(ods_data_type, 'NULL')

        when change_type = 'MISSING_IN_ODS' then
            'MISSING_IN_ODS: column '
            || column_name
            || ' exists in staging but missing in ods. staging type='
            || coalesce(staging_data_type, 'NULL')

        when change_type = 'EXTRA_IN_ODS' then
            'EXTRA_IN_ODS: column '
            || column_name
            || ' exists in ods but missing in staging. ods type='
            || coalesce(ods_data_type, 'NULL')

        else
            'UNKNOWN_SCHEMA_CHANGE: column ' || column_name
    end as log_message
from all_issues

{% endmacro %}