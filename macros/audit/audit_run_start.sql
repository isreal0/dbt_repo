{% macro audit_run_start() %}

    {% if execute and flags.WHICH != 'compile' %}

        {% set job_name = var('job_name', 'manual_dbt_run') %}
        {% set project_name_var = var('project_name', project_name) %}
        {% set trigger_type = var('trigger_type', 'MANUAL') %}
        {% set trigger_source = var('trigger_source', 'dbt Cloud IDE') %}
        {% set business_date = var('business_date', '') %}
        {% set git_version = var('git_version', '') %}

        {% set cleanup_compile_sql %}
            delete from audit.run
            where lower(command_name) = 'compile'
              and upper(status) in ('STARTED', 'START')
              and job_name = '{{ job_name }}'
              and project_name = '{{ project_name_var }}'
              and target_name = '{{ target.name }}';
        {% endset %}

        {% do run_query(cleanup_compile_sql) %}

        {% set sql %}
            insert into audit.run (
                invocation_id,
                job_name,
                project_name,
                trigger_type,
                trigger_source,
                business_date,
                command_name,
                target_name,
                status,
                started_at,
                git_version,
                created_at
            )
            values (
                '{{ invocation_id }}',
                '{{ job_name }}',
                '{{ project_name_var }}',
                '{{ trigger_type }}',
                '{{ trigger_source }}',
                {% if business_date != '' %}
                    cast('{{ business_date }}' as date),
                {% else %}
                    null,
                {% endif %}
                '{{ flags.WHICH }}',
                '{{ target.name }}',
                'STARTED',
                getdate(),
                nullif('{{ git_version }}', ''),
                getdate()
            );
        {% endset %}

        {% do run_query(sql) %}

    {% endif %}

{% endmacro %}
