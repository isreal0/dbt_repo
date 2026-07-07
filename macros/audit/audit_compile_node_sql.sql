{% macro audit_compile_node_sql(node) %}

    {# 1. If dbt provides real compiled SQL, use it #}

    {% if node.compiled_code is defined and node.compiled_code %}
        {{ return(node.compiled_code) }}
    {% elif node.compiled_sql is defined and node.compiled_sql %}
        {{ return(node.compiled_sql) }}
    {% endif %}


    {# 2. Otherwise use raw SQL #}

    {% if node.raw_code is defined and node.raw_code %}
        {% set sql_text = node.raw_code %}
    {% elif node.raw_sql is defined and node.raw_sql %}
        {% set sql_text = node.raw_sql %}
    {% else %}
        {{ return('') }}
    {% endif %}


    {# 3. Remove config block #}

    {% if modules.re is defined %}
        {% set sql_text = modules.re.sub('\\{\\{\\s*config\\(.*?\\)\\s*\\}\\}', '', sql_text, flags=modules.re.DOTALL) %}
    {% endif %}


    {# 4. Hard-code replacement for current source #}

    {% set source_relation = '"demo_shared_db"."demo_datashare"."policy"' %}

    {% set lb = '{{' %}
    {% set rb = '}}' %}

    {% set src_expr_1 = lb ~ " source('demo_datashare', 'policy') " ~ rb %}
    {% set src_expr_2 = lb ~ "source('demo_datashare', 'policy')" ~ rb %}
    {% set src_expr_3 = lb ~ " source(\"demo_datashare\", \"policy\") " ~ rb %}
    {% set src_expr_4 = lb ~ "source(\"demo_datashare\", \"policy\")" ~ rb %}

    {% set sql_text = sql_text | replace(src_expr_1, source_relation) %}
    {% set sql_text = sql_text | replace(src_expr_2, source_relation) %}
    {% set sql_text = sql_text | replace(src_expr_3, source_relation) %}
    {% set sql_text = sql_text | replace(src_expr_4, source_relation) %}


    {# 5. Replace current known ref if needed #}

    {% set stg_relation = '"' ~ target.database ~ '"."' ~ target.schema ~ '"."stg_policy"' %}

    {% set ref_expr_1 = lb ~ " ref('stg_policy') " ~ rb %}
    {% set ref_expr_2 = lb ~ "ref('stg_policy')" ~ rb %}
    {% set ref_expr_3 = lb ~ " ref(\"stg_policy\") " ~ rb %}
    {% set ref_expr_4 = lb ~ "ref(\"stg_policy\")" ~ rb %}

    {% set sql_text = sql_text | replace(ref_expr_1, stg_relation) %}
    {% set sql_text = sql_text | replace(ref_expr_2, stg_relation) %}
    {% set sql_text = sql_text | replace(ref_expr_3, stg_relation) %}
    {% set sql_text = sql_text | replace(ref_expr_4, stg_relation) %}


    {# 6. Replace this if used #}

    {% if node.database is defined and node.schema is defined and node.alias is defined %}
        {% set this_relation = '"' ~ node.database ~ '"."' ~ node.schema ~ '"."' ~ node.alias ~ '"' %}
        {% set this_expr_1 = lb ~ " this " ~ rb %}
        {% set this_expr_2 = lb ~ "this" ~ rb %}

        {% set sql_text = sql_text | replace(this_expr_1, this_relation) %}
        {% set sql_text = sql_text | replace(this_expr_2, this_relation) %}
    {% endif %}

    {{ return(sql_text | trim) }}

{% endmacro %}