# ═══════════════════════════════════════════════════════════════════════
# Stage 1 │ BUILDER
# Purpose : Install Python deps + carry the Dataflow launcher binary.
#           ALL build-time tools (curl, gcc, etc.) stay here — they
#           never reach the final image.
# ═══════════════════════════════════════════════════════════════════════
FROM gcr.io/dataflow-templates-base/python311-template-launcher-base:20260122-rc00 AS builder

# Upgrade ALL OS packages in the builder to patch known CVEs.
# We don't care about the builder's vuln count — only the final stage.
RUN apt-get update -qq && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends \
        default-jre-headless && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy and install Python dependencies
COPY requirements.txt /build/requirements.txt

RUN pip install --no-cache-dir \
        --root-user-action=ignore \
        --upgrade pip setuptools wheel && \
    pip install --no-cache-dir \
        --root-user-action=ignore \
        -r /build/requirements.txt && \
    pip cache purge

# ── Capture Java home so we can copy exactly that path later ─────────
RUN java -XshowSettings:all -version 2>&1 | \
    grep "java.home" | awk '{print $3}' > /tmp/java_home.txt && \
    cat /tmp/java_home.txt

# ═══════════════════════════════════════════════════════════════════════
# Stage 2 │ RUNTIME — Distroless Python 3.11 (Debian 12)
#
# gcr.io/distroless/python3-debian12:nonroot contains:
#   ✅  Python 3.11 runtime
#   ✅  glibc (same Debian 12 ABI as the builder)
#   ✅  ca-certificates
#   ❌  No shell  → no CVEs from bash/dash
#   ❌  No apt    → no package-manager attack surface
#   ❌  No curl   → removed from runtime entirely
#   ❌  No login  → runs as UID 65532 (nonroot) by default
# ═══════════════════════════════════════════════════════════════════════
FROM gcr.io/distroless/python3-debian12:nonroot AS runtime

# ── Dataflow launcher binary (Go binary, statically linked) ──────────
COPY --from=builder /opt/google/dataflow /opt/google/dataflow

# ── Java runtime  (Dataflow worker harness requires JVM) ─────────────
# Copy only the JRE directory — NOT the full JDK toolchain
COPY --from=builder /usr/lib/jvm/java-17-openjdk-amd64 \
                    /usr/lib/jvm/java-17-openjdk-amd64
COPY --from=builder /etc/alternatives/java \
                    /usr/bin/java 2>/dev/null || true

# ── Python packages installed in builder ─────────────────────────────
COPY --from=builder /usr/local/lib/python3.11 /usr/local/lib/python3.11
COPY --from=builder /usr/local/bin/python3.11  /usr/local/bin/python3.11

# ── Application files (distroless nonroot = UID 65532) ───────────────
COPY --chown=65532:65532 requirements.txt       /template/requirements.txt
COPY --chown=65532:65532 oden_pubsub_to_gcs.py  /template/oden_pubsub_to_gcs.py

# ── Environment ───────────────────────────────────────────────────────
ENV FLEX_TEMPLATE_PYTHON_PY_FILE="/template/oden_pubsub_to_gcs.py"
ENV JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
ENV PATH="${JAVA_HOME}/bin:${PATH}"

WORKDIR /template

# nonroot user is already set by the distroless base (UID 65532)
# USER is inherited — no need to re-declare

ENTRYPOINT ["/opt/google/dataflow/python_template_launcher"]