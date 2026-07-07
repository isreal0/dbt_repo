{% macro audit_object_pre_run() %}

    {% if execute and model.resource_type == 'model' %}

        {% set relation_exists = adapter.get_relation(
            database=this.database,
            schema=this.schema,
            identifier=this.identifier
        ) %}

        {% if relation_exists is not none %}
            {% set pre_count_sql %}
                select count(*) as row_count from {{ this }}
            {% endset %}
            {% set pre_count_result = run_query(pre_count_sql) %}
            {% set pre_count = pre_count_result.columns[0].values()[0] %}
        {% else %}
            {% set pre_count = none %}
        {% endif %}

        {% set sql %}
            insert into audit.object (
                audit_run_id,
                invocation_id,
                model_name,
                unique_id,
                database_name,
                schema_name,
                object_name,
                object_type,
                resource_type,
                materialized,
                status,
                started_at,
                pre_run_row_count,
                compiled_sql,
                created_at,
                updated_at
            )
            select
                audit_run_id,
                '{{ invocation_id }}',
                '{{ model.name }}',
                '{{ model.unique_id }}',
                '{{ this.database }}',
                '{{ this.schema }}',
                '{{ this.identifier }}',
                upper('{{ model.config.materialized }}'),
                '{{ model.resource_type }}',
                '{{ model.config.materialized }}',
                'STARTED',
                getdate(),
                {% if pre_count is not none %}
                    {{ pre_count }},
                {% else %}
                    null,
                {% endif %}
                null,
                getdate(),
                getdate()
            from audit.run
            where invocation_id = '{{ invocation_id }}'
            order by started_at desc
            limit 1;
        {% endset %}

        {% do run_query(sql) %}

    {% endif %}

{% endmacro %}