-- =============================================================================
-- Model : eds_stg_customers
-- Layer : EDS (Enterprise Data Store) — Staging
-- Type  : VIEW (no physical storage — always reads live from raw source)
-- Target: BigQuery dataset raw_eds
-- =============================================================================
-- PURPOSE:
--   First transformation layer on top of raw.raw_customers.
--   Cleans, casts, and renames columns from the raw ingestion format into
--   typed, standardised fields that downstream ODS models can safely join on.
--
-- SOURCE:
--   raw.raw_customers — declared in _eds_sources.yml
--   All columns arrive as STRING because the ingestion layer writes raw CSV/JSON.
--
-- TRANSFORMATIONS APPLIED:
--   customer_id   → cast STRING → INT64   (enables integer joins in ODS layer)
--   first_name    → trim whitespace        (removes leading/trailing spaces from source)
--   last_name     → trim whitespace
--   email         → lower + trim          (normalise casing for deduplication/lookups)
--   created_at    → cast STRING → TIMESTAMP (enables date arithmetic in ODS layer)
--   column rename → created_at → account_created_at (clearer business name)
--
-- CONSUMED BY:
--   ods_customer_orders — joins this model with eds_stg_orders on customer_id
-- =============================================================================

with source as (
    -- Pull all columns from the declared source table.
    -- {{ source('raw', 'raw_customers') }} resolves to:
    -- `southwire-poc.raw.raw_customers` using the database/schema in _eds_sources.yml
    select * from {{ source('raw', 'raw_customers') }}
),

staged as (
    select
        -- Cast to INT64: raw source sends customer_id as STRING.
        -- Downstream joins in ods_customer_orders use integer equality.
        cast(customer_id as int64)              as customer_id,

        -- Trim whitespace: source data can have spaces from CSV parsing.
        trim(first_name)                        as first_name,
        trim(last_name)                         as last_name,

        -- Normalise email: lowercase + trim ensures consistent lookups.
        -- e.g. "Alice@Example.com " → "alice@example.com"
        lower(trim(email))                      as email,

        -- Cast and rename: source stores as ISO string "2025-06-01T00:00:00Z".
        -- TIMESTAMP type enables date arithmetic (e.g. days since account creation).
        -- Renamed from created_at → account_created_at for business clarity.
        cast(created_at as timestamp)           as account_created_at

    from source
)

select * from staged
