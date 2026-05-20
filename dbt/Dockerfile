FROM python:3.13.13-alpine3.22 AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apk add --no-cache \
        git \
        gcc \
        musl-dev \
        libffi-dev \
        ca-certificates \
        bash \
    && apk upgrade --no-cache xz

# CVE-2025-8869, CVE-2026-1703, CVE-2026-3219 → pip>=26.1
# CVE-2026-23949, CVE-2026-6357              → setuptools>=80.10.1
# CVE-2026-24049                              → wheel>=0.46.2
RUN pip install --no-cache-dir \
        "pip>=26.1" \
        "setuptools>=80.10.1" \
        "wheel>=0.46.2"

# CVE-2026-29790  → dbt-common>=1.37.3
# CVE-2025-58367,
# CVE-2026-33155  → deepdiff>=8.6.2
# Pre-install patched floor versions BEFORE dbt so pip won't downgrade them.
RUN pip install --no-cache-dir --prefix=/install \
        "dbt-common>=1.37.3" \
        "deepdiff>=8.6.2"

# dbt-core 1.11.11 is the latest stable patch (released May 20, 2026).
# dbt-bigquery 1.11.1 is the matching adapter on the Compatible release track.
RUN pip install --no-cache-dir --prefix=/install \
        "dbt-core==1.11.11" \
        "dbt-bigquery==1.11.1"

WORKDIR /dbt
COPY dbt_project.yml .
COPY profiles.yml    .
COPY packages.yml    .
COPY models/         models/
COPY macros/         macros/
COPY tests/          tests/
COPY seeds/          seeds/
COPY snapshots/      snapshots/

# python3.13 matches the python:3.13.13-alpine3.22 base image above.
RUN PYTHONPATH=/install/lib/python3.13/site-packages \
    /install/bin/dbt deps --profiles-dir .

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM python:3.13.13-alpine3.22 AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DBT_LOG_PATH=/dbt/logs \
    DBT_PROFILES_DIR=/dbt

# CVE-2026-34743: runtime image has its own independent base layer — patch xz here too.
RUN apk add --no-cache \
        ca-certificates \
        bash \
    && apk upgrade --no-cache xz

# Runtime pip comes from the base image, not the builder — upgrade independently.
RUN pip install --no-cache-dir \
        "pip>=26.1" \
        "setuptools>=80.10.1" \
        "wheel>=0.46.2"

# Install patched floor versions globally (no --prefix) so they land in the
# real site-packages tree that Python actually searches at runtime.
RUN pip install --no-cache-dir \
        "dbt-common>=1.37.3" \
        "deepdiff>=8.6.2"

# Create non-root user BEFORE setting permissions
RUN adduser -D -H -s /sbin/nologin dbt

# Copy the full dbt + dependency tree from the builder
COPY --from=builder /install /usr/local

# Copy dbt project, pre-owned by the dbt user
COPY --chown=dbt:dbt --from=builder /dbt /dbt

RUN mkdir -p \
        /dbt/logs \
        /dbt/target \
        /dbt/dbt_packages \
    && chown -R dbt:dbt \
        /dbt/logs \
        /dbt/target \
        /dbt/dbt_packages \
    && chmod -R 755 \
        /dbt/logs \
        /dbt/target \
        /dbt/dbt_packages

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r//' /entrypoint.sh && \
    chmod +x /entrypoint.sh

HEALTHCHECK --interval=30s \
            --timeout=10s \
            --start-period=10s \
            --retries=3 \
    CMD bash -c " \
        test -x /usr/local/bin/dbt        || exit 1; \
        test -x /entrypoint.sh            || exit 1; \
        python --version > /dev/null 2>&1 || exit 1; \
        dbt --version > /dev/null 2>&1    || exit 1 \
    "

USER dbt

WORKDIR /dbt

ENTRYPOINT ["/entrypoint.sh"]