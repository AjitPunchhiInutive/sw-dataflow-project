# ── Stage 1: Builder ──────────────────────────────────────────────────────────
FROM python:3.14.4-alpine3.22 AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# BUG FIX #3: restore build toolchain that was missing from this stage.
# gcc + musl-dev are required to compile C extensions (grpcio, protobuf, etc.)
# that dbt-bigquery pulls in. Without them, `pip install dbt-bigquery` fails.
# CVE-2026-34743: `apk upgrade xz` patches the heap buffer overflow in
# lzma_index_append() (xz >=5.8.3).
RUN apk add --no-cache \
        git \
        gcc \
        musl-dev \
        libffi-dev \
        ca-certificates \
        bash \
    && apk upgrade --no-cache xz

# CVE-2025-8869, CVE-2026-1703, CVE-2026-3219 → pip>=26.1
# CVE-2026-23949, CVE-2026-6357          → setuptools>=80.10.1
# CVE-2026-24049                          → wheel>=0.46.2
RUN pip install --no-cache-dir \
        "pip>=26.1" \
        "setuptools>=80.10.1" \
        "wheel>=0.46.2"

# CVE-2026-29790  → dbt-common>=1.37.3  (os.path.commonprefix path traversal)
# CVE-2025-58367,
# CVE-2026-33155  → deepdiff>=8.6.2     (class pollution RCE + memory exhaustion DoS)
# Pre-install patched floor versions BEFORE dbt so pip won't downgrade them.
RUN pip install --no-cache-dir --prefix=/install \
        "dbt-common>=1.37.3" \
        "deepdiff>=8.6.2"

# VERSION FIX: dbt-core 1.11.1 is yanked ("Issues with installs in some
# environments"). Use 1.11.10 — the latest stable patch on the 1.11.x line.
# dbt-bigquery 1.11.1 is the matching adapter on the Compatible release track.
RUN pip install --no-cache-dir --prefix=/install \
        "dbt-core==1.11.10" \
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

# BUG FIX #2: python3.11 → python3.14 to match the python:3.14.4-alpine3.22
# base image. Using the wrong minor version means Python silently skips the
# entire /install/lib/python3.11/site-packages tree, making dbt invisible.
RUN PYTHONPATH=/install/lib/python3.14/site-packages \
    /install/bin/dbt deps --profiles-dir .

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM python:3.14.4-alpine3.22 AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DBT_LOG_PATH=/dbt/logs \
    DBT_PROFILES_DIR=/dbt

# CVE-2026-34743: patch xz in the runtime image independently of the builder —
# each FROM starts from a fresh base layer with its own copy of the OS packages.
RUN apk add --no-cache \
        ca-certificates \
        bash \
    && apk upgrade --no-cache xz

# Upgrade pip/setuptools/wheel in the runtime image too.
# The entrypoint calls `dbt deps`, which may invoke pip internally.
# This image's pip comes from the base layer, not from the builder stage.
RUN pip install --no-cache-dir \
        "pip>=26.1" \
        "setuptools>=80.10.1" \
        "wheel>=0.46.2"

# BUG FIX #4: removed `--prefix=/install` that was here before.
# With --prefix=/install, packages land in /install/lib/python3.14/site-packages
# but nothing adds /install to PYTHONPATH at runtime, so they are never found.
# Installing globally (no --prefix) puts them in the real site-packages tree.
RUN pip install --no-cache-dir \
        "dbt-common>=1.37.3" \
        "deepdiff>=8.6.2"

# Create non-root user BEFORE setting permissions
RUN adduser -D -H -s /sbin/nologin dbt

# Copy the full dbt + dependency tree built in Stage 1
COPY --from=builder /install /usr/local

# Copy dbt project, pre-owned by the dbt user
COPY --chown=dbt:dbt --from=builder /dbt /dbt

# Create writable runtime directories
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