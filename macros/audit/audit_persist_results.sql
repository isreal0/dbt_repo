{% macro audit_persist_results(results) %}

    {% if execute %}

        {% do print('AUDIT DEBUG: audit_persist_results started. invocation_id=' ~ invocation_id) %}

        {% for result in results %}

            {% set node = result.node %}
            {% set status_lower = result.status | lower %}
            {% set status_upper = result.status | upper %}
            {% set result_execution_time = result.execution_time | default(0) %}
            {% set result_message = result.message | default('') | string | replace("'", "''") %}

            {% do print(
                'AUDIT DEBUG RESULT: resource_type=' ~ node.resource_type
                ~ ', node_name=' ~ node.name
                ~ ', status=' ~ result.status
                ~ ', unique_id=' ~ node.unique_id
            ) %}

            {# ========================================================
               MODEL RESULT
               ======================================================== #}

            {% if node.resource_type == 'model' %}

                {% set relation = adapter.get_relation(
                    database=node.database,
                    schema=node.schema,
                    identifier=node.alias
                ) %}

                {% if relation is not none and status_lower not in ['error', 'fail', 'failed', 'skipped'] %}

                    {% set post_count_sql %}
                        select count(*) as row_count
                        from {{ relation }}
                    {% endset %}

                    {% set post_count_result = run_query(post_count_sql) %}

                    {% if post_count_result is not none and post_count_result.columns[0].values() | length > 0 %}
                        {% set post_count = post_count_result.columns[0].values()[0] %}
                    {% else %}
                        {% set post_count = none %}
                    {% endif %}

                {% else %}

                    {% set post_count = none %}

                {% endif %}

                {% set compiled_sql = audit_compile_node_sql(node) | string | replace("'", "''") %}

                {# Update existing model row created by audit_object_pre_run #}

                {% set update_model_sql %}
                    update audit."object"
                    set
                        status = '{{ status_upper }}',
                        completed_at = getdate(),
                        duration_seconds = {{ result_execution_time }},
                        post_run_row_count =
                            {% if post_count is not none %}
                                {{ post_count }}
                            {% else %}
                                null
                            {% endif %},
                        compiled_sql = nullif('{{ compiled_sql[:65000] }}', ''),
                        error_code =
                            {% if status_lower in ['error', 'fail', 'failed'] %}
                                'DBT_MODEL_FAILED'
                            {% else %}
                                null
                            {% endif %},
                        error_message =
                            {% if status_lower in ['error', 'fail', 'failed'] %}
                                nullif('{{ result_message[:65000] }}', '')
                            {% else %}
                                null
                            {% endif %},
                        updated_at = getdate()
                    where invocation_id = '{{ invocation_id }}'
                      and unique_id = '{{ node.unique_id }}'
                {% endset %}

                {% do run_query(update_model_sql) %}


                {# Fallback insert if no STARTED row exists #}

                {% set insert_missing_model_sql %}
                    insert into audit."object" (
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
                        completed_at,
                        duration_seconds,
                        pre_run_row_count,
                        post_run_row_count,
                        rows_affected,
                        rows_inserted,
                        rows_updated,
                        rows_deleted,
                        compiled_sql,
                        test_status,
                        test_count,
                        test_passed_count,
                        test_failed_count,
                        error_code,
                        error_message,
                        created_at,
                        updated_at
                    )
                    select
                        r.audit_run_id,
                        '{{ invocation_id }}',
                        '{{ node.name }}',
                        '{{ node.unique_id }}',
                        '{{ node.database }}',
                        '{{ node.schema }}',
                        '{{ node.alias }}',
                        upper('{{ node.config.materialized }}'),
                        '{{ node.resource_type }}',
                        '{{ node.config.materialized }}',
                        '{{ status_upper }}',
                        r.started_at,
                        getdate(),
                        {{ result_execution_time }},
                        null,
                        {% if post_count is not none %}
                            {{ post_count }},
                        {% else %}
                            null,
                        {% endif %}
                        null,
                        null,
                        null,
                        null,
                        nullif('{{ compiled_sql[:65000] }}', ''),
                        null,
                        null,
                        null,
                        null,
                        {% if status_lower in ['error', 'fail', 'failed'] %}
                            'DBT_MODEL_FAILED',
                            nullif('{{ result_message[:65000] }}', ''),
                        {% else %}
                            null,
                            null,
                        {% endif %}
                        getdate(),
                        getdate()
                    from audit."run" r
                    where r.invocation_id = '{{ invocation_id }}'
                      and not exists (
                          select 1
                          from audit."object" o
                          where o.invocation_id = '{{ invocation_id }}'
                            and o.unique_id = '{{ node.unique_id }}'
                      )
                    order by r.started_at desc
                    limit 1
                {% endset %}

                {% do run_query(insert_missing_model_sql) %}


            {# ========================================================
               TEST RESULT
               ======================================================== #}

            {% elif node.resource_type in ['test', 'data_test'] %}

                {% set compiled_sql = audit_compile_node_sql(node) | string | replace("'", "''") %}

                {% set insert_test_sql %}
                    insert into audit."object" (
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
                        completed_at,
                        duration_seconds,
                        pre_run_row_count,
                        post_run_row_count,
                        rows_affected,
                        rows_inserted,
                        rows_updated,
                        rows_deleted,
                        compiled_sql,
                        test_status,
                        test_count,
                        test_passed_count,
                        test_failed_count,
                        error_code,
                        error_message,
                        created_at,
                        updated_at
                    )
                    select
                        r.audit_run_id,
                        '{{ invocation_id }}',
                        '{{ node.name }}',
                        '{{ node.unique_id }}',
                        '{{ node.database }}',
                        '{{ node.schema }}',
                        '{{ node.alias }}',
                        'TEST',
                        'test',
                        null,
                        '{{ status_upper }}',
                        r.started_at,
                        getdate(),
                        {{ result_execution_time }},
                        null,
                        null,
                        {% if result.failures is defined and result.failures is not none %}
                            {{ result.failures }},
                        {% else %}
                            null,
                        {% endif %}
                        null,
                        null,
                        null,
                        nullif('{{ compiled_sql[:65000] }}', ''),
                        '{{ status_upper }}',
                        1,
                        {% if status_lower in ['pass', 'success'] %}
                            1,
                            0,
                        {% elif status_lower in ['error', 'fail', 'failed'] %}
                            0,
                            1,
                        {% else %}
                            0,
                            0,
                        {% endif %}
                        {% if status_lower in ['error', 'fail', 'failed'] %}
                            'DBT_TEST_FAILED',
                            nullif('{{ result_message[:65000] }}', ''),
                        {% else %}
                            null,
                            null,
                        {% endif %}
                        getdate(),
                        getdate()
                    from audit."run" r
                    where r.invocation_id = '{{ invocation_id }}'
                    order by r.started_at desc
                    limit 1
                {% endset %}

                {% do print('AUDIT DEBUG insert_test_sql START') %}
                {% do print(insert_test_sql) %}
                {% do print('AUDIT DEBUG insert_test_sql END') %}

                {% do run_query(insert_test_sql) %}

            {% endif %}

        {% endfor %}


        {# ============================================================
           Update model test summary
           ============================================================ #}

        {% set update_model_test_summary_sql %}
            update audit."object" o
            set
                test_count = s.test_count,
                test_passed_count = s.test_passed_count,
                test_failed_count = s.test_failed_count,
                test_status =
                    case
                        when s.test_count = 0 then 'NOT_RUN'
                        when s.test_failed_count > 0 then 'FAIL'
                        else 'PASS'
                    end,
                updated_at = getdate()
            from (
                select
                    audit_run_id,
                    count(*) as test_count,
                    sum(
                        case
                            when upper(coalesce(status, '')) in ('PASS', 'SUCCESS')
                            then 1
                            else 0
                        end
                    ) as test_passed_count,
                    sum(
                        case
                            when upper(coalesce(status, '')) in ('FAIL', 'FAILED', 'ERROR')
                            then 1
                            else 0
                        end
                    ) as test_failed_count
                from audit."object"
                where invocation_id = '{{ invocation_id }}'
                  and resource_type = 'test'
                group by audit_run_id
            ) s
            where o.audit_run_id = s.audit_run_id
              and o.resource_type = 'model'
        {% endset %}

        {% do run_query(update_model_test_summary_sql) %}


        {# ============================================================
           Default model test summary when no tests exist
           ============================================================ #}

        {% set default_model_test_status_sql %}
            update audit."object"
            set
                test_status = coalesce(test_status, 'NOT_RUN'),
                test_count = coalesce(test_count, 0),
                test_passed_count = coalesce(test_passed_count, 0),
                test_failed_count = coalesce(test_failed_count, 0),
                updated_at = getdate()
            where invocation_id = '{{ invocation_id }}'
              and resource_type = 'model'
        {% endset %}

        {% do run_query(default_model_test_status_sql) %}


        {# ============================================================
           Update audit.run final status
           Redshift-safe version: aggregate first, then update from summary.
           No correlated subquery in SET clause.
           ============================================================ #}

        {% set update_run_sql %}
            update audit."run" r
            set
                status =
                    case
                        when s.fail_object_count > 0 then 'FAILED'
                        else 'SUCCESS'
                    end,

                completed_at = getdate(),

                duration_seconds = datediff(milliseconds, r.started_at, getdate()) / 1000.0,

                success_object_count = s.success_object_count,
                fail_object_count = s.fail_object_count,
                skipped_object_count = s.skipped_object_count,

                error_code =
                    case
                        when s.fail_object_count > 0 then 'DBT_RUN_FAILED'
                        else null
                    end,

                error_message =
                    case
                        when s.fail_object_count > 0 then s.failed_message
                        else null
                    end,

                updated_at = getdate()

            from (
                select
                    c.audit_run_id,
                    c.success_object_count,
                    c.fail_object_count,
                    c.skipped_object_count,
                    f.failed_message
                from (
                    select
                        audit_run_id,

                        sum(
                            case
                                when upper(coalesce(status, '')) in ('SUCCESS', 'PASS')
                                then 1
                                else 0
                            end
                        ) as success_object_count,

                        sum(
                            case
                                when upper(coalesce(status, '')) in ('FAIL', 'FAILED', 'ERROR')
                                then 1
                                else 0
                            end
                        ) as fail_object_count,

                        sum(
                            case
                                when upper(coalesce(status, '')) = 'SKIPPED'
                                then 1
                                else 0
                            end
                        ) as skipped_object_count

                    from audit."object"
                    where invocation_id = '{{ invocation_id }}'
                    group by audit_run_id
                ) c

                left join (
                    select
                        audit_run_id,
                        'Failed objects: '
                        || listagg(
                            coalesce(model_name, unique_id, 'UNKNOWN_OBJECT'),
                            ', '
                        ) within group (order by audit_object_id) as failed_message
                    from audit."object"
                    where invocation_id = '{{ invocation_id }}'
                      and upper(coalesce(status, '')) in ('FAIL', 'FAILED', 'ERROR')
                    group by audit_run_id
                ) f
                    on c.audit_run_id = f.audit_run_id

            ) s

            where r.audit_run_id = s.audit_run_id
        {% endset %}

        {% do print('AUDIT DEBUG update_run_sql START') %}
        {% do print(update_run_sql) %}
        {% do print('AUDIT DEBUG update_run_sql END') %}

        {% do run_query(update_run_sql) %}

    {% endif %}

{% endmacro %}