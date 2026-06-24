-- =============================================================================
-- Model : eds_stg_orders
-- Layer : EDS (Enterprise Data Store) — Staging
-- Type  : VIEW (no physical storage — always reads live from raw source)
-- Target: BigQuery dataset raw_eds
-- =============================================================================
-- PURPOSE:
--   First transformation layer on top of raw.raw_orders.
--   Cleans, casts, and renames all columns so the ODS layer receives
--   typed data with consistent naming — no business logic here, only
--   structural cleaning.
--
-- SOURCE:
--   raw.raw_orders — declared in _eds_sources.yml
--   All columns arrive as STRING because the ingestion layer writes raw CSV/JSON.
--
-- TRANSFORMATIONS APPLIED:
--   order_id      → cast STRING → INT64       (enables integer joins in ODS)
--   customer_id   → cast STRING → INT64       (foreign key join to eds_stg_customers)
--   order_date    → cast STRING → DATE        (enables date comparisons in ODS)
--   status        → upper + trim → order_status
--                                             (normalise casing: "completed" → "COMPLETED")
--                                             (rename: status → order_status for clarity)
--   amount        → cast STRING → NUMERIC → order_amount
--                                             (NUMERIC preserves decimal precision for money)
--                                             (rename: amount → order_amount for clarity)
--
-- CONSUMED BY:
--   ods_customer_orders — joins this model with eds_stg_customers on customer_id
-- =============================================================================

with source as (
    -- Pull all columns from the declared source table.
    -- {{ source('raw', 'raw_orders') }} resolves to:
    -- `southwire-poc.raw.raw_orders` using the database/schema in _eds_sources.yml
    select * from {{ source('raw', 'raw_orders') }}
),

staged as (
    select
        -- Cast to INT64: raw source sends order_id as STRING.
        cast(order_id as int64)       as order_id,

        -- Cast to INT64: foreign key used to join with eds_stg_customers.
        cast(customer_id as int64)    as customer_id,

        -- Cast to DATE: raw source stores as "2026-01-10" string.
        -- DATE type enables min/max date comparisons in ods_customer_orders.
        cast(order_date as date)      as order_date,

        -- Normalise status: uppercase + trim handles inconsistent source casing.
        -- e.g. "completed", "Completed ", "COMPLETED" → all become "COMPLETED"
        -- _eds_models.yml tests this column against accepted_values.
        upper(trim(status))           as order_status,

        -- Cast to NUMERIC: preserves exact decimal precision for monetary values.
        -- Renamed from 'amount' to 'order_amount' for clarity in downstream models.
        cast(amount as numeric)       as order_amount

    from source
)

select * from staged
