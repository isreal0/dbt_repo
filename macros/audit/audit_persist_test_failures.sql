{% macro audit_persist_test_failures(results) %}

    {% if execute %}

        {% for result in results %}

            {% set node = result.node %}
            {% set status_lower = result.status | lower %}
            {% set status_upper = result.status | upper %}
            {% set result_message = result.message | default('') | string | replace("'", "''") %}
            {% set compiled_sql = audit_compile_node_sql(node) | string | replace("'", "''") %}

            {% if node.resource_type in ['test', 'data_test']
                  and status_lower in ['error', 'fail', 'failed'] %}

                {# =====================================================
                   1. Insert failed test summary row
                   ===================================================== #}

                {% set insert_summary_sql %}
                    insert into audit.test_failure_log (
                        audit_run_id,
                        invocation_id,
                        test_name,
                        unique_id,
                        test_status,
                        failure_count,
                        related_model_name,
                        detail_type,
                        error_message,
                        compiled_sql,
                        created_at
                    )
                    select
                        o.audit_run_id,
                        '{{ invocation_id }}',
                        '{{ node.name }}',
                        '{{ node.unique_id }}',
                        '{{ status_upper }}',
                        {% if result.failures is defined and result.failures is not none %}
                            {{ result.failures }},
                        {% else %}
                            null,
                        {% endif %}
                        '{{ node.name }}',
                        'TEST_SUMMARY',
                        nullif('{{ result_message[:65000] }}', ''),
                        nullif('{{ compiled_sql[:65000] }}', ''),
                        getdate()
                    from audit."object" o
                    where o.invocation_id = '{{ invocation_id }}'
                      and o.unique_id = '{{ node.unique_id }}'
                      and o.resource_type = 'test'
                    order by o.audit_object_id desc
                    limit 1
                {% endset %}

                {% do run_query(insert_summary_sql) %}


                {# =====================================================
                   2. For compare_stg_to_ods_schema, get schema diff rows
                      using run_query first, then insert each row by VALUES.
                   ===================================================== #}

                {% if node.name.startswith('compare_stg_to_ods_schema') %}

                    {% set raw_stg_table = node.name | replace('compare_stg_to_ods_schema_', '') %}

                    {% if raw_stg_table.endswith('_') %}
                        {% set stg_table = raw_stg_table[:-1] %}
                    {% else %}
                        {% set stg_table = raw_stg_table %}
                    {% endif %}

                    {% set ods_table = stg_table | replace('stg_', 'ods_') %}

                    {% set diff_sql %}
                        {{ schema_diff_sql(
                            target.database,
                            target.schema,
                            stg_table,
                            target.database,
                            target.schema,
                            ods_table
                        ) }}
                    {% endset %}

                    {% set diff_result = run_query(diff_sql) %}

                    {% if diff_result is not none and diff_result.columns[0].values() | length > 0 %}

                        {% set row_count = diff_result.columns[0].values() | length %}

                        {% set staging_relation_values = diff_result.columns[1].values() %}
                        {% set ods_relation_values = diff_result.columns[2].values() %}
                        {% set change_type_values = diff_result.columns[3].values() %}
                        {% set column_name_values = diff_result.columns[4].values() %}
                        {% set staging_data_type_values = diff_result.columns[5].values() %}
                        {% set ods_data_type_values = diff_result.columns[6].values() %}
                        {% set staging_ordinal_position_values = diff_result.columns[7].values() %}
                        {% set ods_ordinal_position_values = diff_result.columns[8].values() %}
                        {% set log_message_values = diff_result.columns[9].values() %}

                        {% for i in range(row_count) %}

                            {% set staging_relation = staging_relation_values[i] %}
                            {% set ods_relation = ods_relation_values[i] %}
                            {% set change_type = change_type_values[i] %}
                            {% set column_name = column_name_values[i] %}
                            {% set staging_data_type = staging_data_type_values[i] %}
                            {% set ods_data_type = ods_data_type_values[i] %}
                            {% set staging_ordinal_position = staging_ordinal_position_values[i] %}
                            {% set ods_ordinal_position = ods_ordinal_position_values[i] %}
                            {% set log_message = log_message_values[i] %}

                            {% set insert_schema_detail_row_sql %}
                                insert into audit.test_failure_log (
                                    audit_run_id,
                                    invocation_id,
                                    test_name,
                                    unique_id,
                                    test_status,
                                    failure_count,
                                    related_model_name,
                                    detail_type,

                                    staging_relation,
                                    ods_relation,
                                    change_type,
                                    column_name,
                                    staging_data_type,
                                    ods_data_type,
                                    staging_ordinal_position,
                                    ods_ordinal_position,

                                    error_message,
                                    compiled_sql,
                                    created_at
                                )
                                values (
                                    (
                                        select audit_run_id
                                        from audit."object"
                                        where invocation_id = '{{ invocation_id }}'
                                          and unique_id = '{{ node.unique_id }}'
                                          and resource_type = 'test'
                                        order by audit_object_id desc
                                        limit 1
                                    ),
                                    '{{ invocation_id }}',
                                    '{{ node.name }}',
                                    '{{ node.unique_id }}',
                                    '{{ status_upper }}',
                                    {% if result.failures is defined and result.failures is not none %}
                                        {{ result.failures }},
                                    {% else %}
                                        null,
                                    {% endif %}
                                    '{{ stg_table }}',
                                    'SCHEMA_DIFF_DETAIL',

                                    {% if staging_relation is not none %}
                                        '{{ staging_relation | string | replace("'", "''") }}',
                                    {% else %}
                                        null,
                                    {% endif %}

                                    {% if ods_relation is not none %}
                                        '{{ ods_relation | string | replace("'", "''") }}',
                                    {% else %}
                                        null,
                                    {% endif %}

                                    {% if change_type is not none %}
                                        '{{ change_type | string | replace("'", "''") }}',
                                    {% else %}
                                        null,
                                    {% endif %}

                                    {% if column_name is not none %}
                                        '{{ column_name | string | replace("'", "''") }}',
                                    {% else %}
                                        null,
                                    {% endif %}

                                    {% if staging_data_type is not none %}
                                        '{{ staging_data_type | string | replace("'", "''") }}',
                                    {% else %}
                                        null,
                                    {% endif %}

                                    {% if ods_data_type is not none %}
                                        '{{ ods_data_type | string | replace("'", "''") }}',
                                    {% else %}
                                        null,
                                    {% endif %}

                                    {% if staging_ordinal_position is not none %}
                                        {{ staging_ordinal_position }},
                                    {% else %}
                                        null,
                                    {% endif %}

                                    {% if ods_ordinal_position is not none %}
                                        {{ ods_ordinal_position }},
                                    {% else %}
                                        null,
                                    {% endif %}

                                    {% if log_message is not none %}
                                        '{{ log_message | string | replace("'", "''") }}',
                                    {% else %}
                                        null,
                                    {% endif %}

                                    nullif('{{ compiled_sql[:65000] }}', ''),
                                    getdate()
                                )
                            {% endset %}

                            {% do run_query(insert_schema_detail_row_sql) %}

                        {% endfor %}

                    {% endif %}

                {% endif %}

            {% endif %}

        {% endfor %}

    {% endif %}

{% endmacro %}