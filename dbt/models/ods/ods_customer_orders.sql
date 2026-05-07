-- =============================================================================
-- Model : ods_customer_orders
-- Layer : ODS (Operational Data Store) — Curated
-- Type  : TABLE (physically written to BigQuery on every dbt run)
-- Target: BigQuery dataset raw_ods
-- =============================================================================
-- PURPOSE:
--   The final consumption-ready model. Joins the two EDS staging views and
--   applies business logic to produce a one-row-per-customer summary with
--   order aggregations and a derived customer segment label.
--
-- SOURCES (via ref() — dbt tracks lineage and ensures execution order):
--   eds_stg_customers → cleaned customer dimension (raw_eds dataset, VIEW)
--   eds_stg_orders    → cleaned orders fact (raw_eds dataset, VIEW)
--
-- WHY ref() NOT source():
--   ref() tells dbt this model depends on another dbt model (not a raw table).
--   dbt uses ref() calls to build the execution DAG:
--     eds_stg_customers ──┐
--                         ├──► ods_customer_orders
--     eds_stg_orders   ──┘
--   dbt guarantees the EDS views exist before this model runs.
--
-- JOIN LOGIC:
--   LEFT JOIN customers → orders means every customer appears in the output
--   even if they have zero orders. coalesce handles the NULL amounts.
--
-- BUSINESS LOGIC — customer_segment:
--   0 orders  → 'no_orders' (registered but never purchased)
--   1 order   → 'new'
--   2–5 orders → 'active'
--   6+ orders  → 'loyal'
--
-- MATERIALIZED AS TABLE because:
--   - Aggregations are expensive to recompute on every query
--   - Downstream consumers (BI tools, reports) expect fast query times
--   - The ODS is the "serving layer" — data freshness is controlled by dbt run schedule
-- =============================================================================

with customers as (
    -- ref() creates a dependency on eds_stg_customers.
    -- At runtime this resolves to `southwire-poc.raw_eds.eds_stg_customers`
    select * from {{ ref('eds_stg_customers') }}
),

orders as (
    -- ref() creates a dependency on eds_stg_orders.
    -- At runtime this resolves to `southwire-poc.raw_eds.eds_stg_orders`
    select * from {{ ref('eds_stg_orders') }}
),

customer_orders as (
    select
        -- Customer dimension columns (one row per customer)
        c.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        c.account_created_at,

        -- Order aggregations
        -- count(o.order_id) counts only matched orders (NULLs from LEFT JOIN excluded)
        count(o.order_id)                                                   as total_orders,

        -- Count only orders in a specific terminal status
        sum(case when o.order_status = 'COMPLETED' then 1 else 0 end)      as completed_orders,
        sum(case when o.order_status = 'CANCELLED' then 1 else 0 end)      as cancelled_orders,

        -- coalesce handles customers with 0 orders — sum() returns NULL for no rows
        coalesce(sum(o.order_amount), 0)                                    as lifetime_value,

        -- Date range of customer's order history
        min(o.order_date)                                                   as first_order_date,
        max(o.order_date)                                                   as last_order_date,

        -- Derived segment — uses total_orders count computed in this same SELECT.
        -- BigQuery allows referencing aggregates in CASE within the same SELECT level.
        case
            when count(o.order_id) = 0              then 'no_orders_2'
            when count(o.order_id) = 1              then 'new_2'
            when count(o.order_id) between 2 and 5  then 'active_2'
            else                                         'loyal_2'
        end as customer_segment

    from customers c

    -- LEFT JOIN: retain all customers, even those with no orders in the orders table.
    -- Customers with no orders get NULL for all order columns → handled by coalesce/count above.
    left join orders o
        on c.customer_id = o.customer_id

    -- GROUP BY all non-aggregated columns — BigQuery requires this for aggregate queries
    group by
        c.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        c.account_created_at
)

select * from customer_orders
