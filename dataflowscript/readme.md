# Dataflow Flex Template — CI/CD Pipeline

Automated CI/CD pipeline for building and deploying a Google Cloud Dataflow Flex Template using GitHub Actions. The pipeline reads from a **Pub/Sub subscription**, processes data, and writes to **BigQuery** and **GCS**.

---

## Table of Contents

- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Pipeline Overview](#pipeline-overview)
- [Configuration](#configuration)
- [Prerequisites](#prerequisites)
- [GitHub Secrets](#github-secrets)
- [Workflow Triggers](#workflow-triggers)
- [Deployment Steps](#deployment-steps)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

---

## Architecture

```
Pub/Sub Subscription
        │
        ▼
┌───────────────────┐
│  Dataflow Flex    │
│  Template Job     │  ← Python pipeline (Apache Beam)
└────────┬──────────┘
         │
         ├──► BigQuery (OK records)   pubsub_gcs_dataset.historian_stream
         ├──► BigQuery (Error records) pubsub_gcs_dataset.historian_stream_error
         └──► GCS (raw output files)
```

---

## Repository Structure

```
application/
└── dataflow/
    ├── config.json              # Pipeline configuration (region, project, buckets, etc.)
    ├── Dockerfile               # Custom container image with all dependencies pre-installed
    ├── metadata.json            # Flex Template parameter definitions
    ├── oden_pubsub_to_gcs.py    # Apache Beam pipeline entry point
    └── requirements.txt         # Python dependencies

.github/
└── workflows/
    └── dataflow.yml             # GitHub Actions CI/CD workflow
```

---

## Pipeline Overview

The workflow runs in **4 sequential steps** with a mandatory approval gate:

```
Step 1: Plan     →  Show deployment config + list running jobs
        │
        ▼
Step 2: Approval →  Team member reviews and approves in GitHub UI
        │
        ▼
Step 3: Build    →  Build Docker image → Push to Artifact Registry
                    → Build Flex Template JSON → Upload to GCS
        │
        ▼
Step 4: Deploy   →  Drain existing job → Deploy new Flex Template job
```

---

## Configuration

All pipeline values are stored in `application/dataflow/config.json`. Update this file to change any deployment setting — no workflow edits required.

```json
{
  "dataflow_project":    "sw-dev-prj-sandbox",
  "region":              "us-east4",
  "job_name":            "sw-oden-pubsub-to-gcs",
  "job_filter":          "sw-oden-pubsub-to-gcs",
  "ar_registry":         "us-east4-docker.pkg.dev",
  "ar_repository":       "sw-dev-prj-sandbox/sw-dataflow-template",
  "ar_image_name":       "oden-gcs-parquet",
  "dockerfile_path":     "./application/dataflow/Dockerfile",
  "dockerfile_context":  "./application/dataflow",
  "metadata_file":       "./application/dataflow/metadata.json",
  "gcs_bucket":          "sw-rds-dataflow-gcs-itp",
  "gcs_template_prefix": "templates/oden-gcs-parquet",
  "gcs_output_path":     "gs://sw-rds-dataflow-gcs-itp/output/",
  "gcs_temp_location":   "gs://sw-rds-dataflow-gcs-itp/tmp",
  "gcs_staging_location":"gs://sw-rds-dataflow-gcs-itp/staging",
  "network":             "dataflow-network",
  "subnetwork":          "regions/us-east4/subnetworks/dataflow-subnet",
  "service_account":     "dataflow-runner@sw-dev-prj-sandbox.iam.gserviceaccount.com",
  "subscription":        "projects/sw-dev-prj-sandbox/subscriptions/proficy-historian-topic",
  "bq_table_ok":         "sw-dev-prj-sandbox:pubsub_gcs_dataset.historian_stream",
  "bq_table_err":        "sw-dev-prj-sandbox:pubsub_gcs_dataset.historian_stream_error"
}
```

### Configuration Reference

| Key | Description |
|---|---|
| `dataflow_project` | GCP project where the Dataflow job runs |
| `region` | GCP region for all resources |
| `job_name` | Dataflow streaming job name |
| `job_filter` | Filter used to find and drain existing jobs |
| `ar_registry` | Artifact Registry hostname |
| `ar_repository` | Artifact Registry repository path |
| `ar_image_name` | Docker image name |
| `dockerfile_path` | Path to Dockerfile in the repo |
| `dockerfile_context` | Docker build context directory |
| `metadata_file` | Flex Template metadata JSON path |
| `gcs_bucket` | GCS bucket for templates and output |
| `gcs_template_prefix` | GCS prefix for the template JSON file |
| `gcs_output_path` | GCS destination for processed output files |
| `gcs_temp_location` | Dataflow temp file location |
| `gcs_staging_location` | Dataflow staging file location |
| `network` | VPC network for Dataflow workers |
| `subnetwork` | VPC subnetwork for Dataflow workers |
| `service_account` | Dataflow worker service account |
| `subscription` | Pub/Sub subscription to read from |
| `bq_table_ok` | BigQuery table for successfully processed records |
| `bq_table_err` | BigQuery table for failed/error records |

---

## Prerequisites

The following GCP resources must exist before running the pipeline:

| Resource | Name |
|---|---|
| GCP Project | `sw-dev-prj-sandbox` |
| Artifact Registry | `sw-dataflow-template` |
| GCS Bucket | `sw-rds-dataflow-gcs-itp` |
| VPC Network | `dataflow-network` |
| VPC Subnetwork | `dataflow-subnet` (us-east4) |
| Pub/Sub Subscription | `proficy-historian-topic` |
| BigQuery Dataset | `pubsub_gcs_dataset` |
| BigQuery Tables | `historian_stream`, `historian_stream_error` |
| Service Account | `dataflow-runner@sw-dev-prj-sandbox.iam.gserviceaccount.com` |

### Required IAM Roles for Dataflow Service Account

| Role | Purpose |
|---|---|
| `roles/dataflow.admin` | Create and manage Dataflow jobs |
| `roles/dataflow.worker` | Execute Dataflow job tasks |
| `roles/iam.serviceAccountUser` | Attach service account to the job |
| `roles/storage.objectAdmin` | Read template + write output to GCS |
| `roles/bigquery.dataEditor` | Write rows to BigQuery tables |
| `roles/bigquery.jobUser` | Submit BigQuery jobs |
| `roles/pubsub.subscriber` | Pull messages from subscription |
| `roles/pubsub.viewer` | Read subscription metadata |
| `roles/artifactregistry.reader` | Pull Docker image from Artifact Registry |

---

## GitHub Secrets

Configure the following secrets under **GitHub → Settings → Secrets and variables → Actions → Secrets**:

| Secret | Description |
|---|---|
| `GCP_PROJECT_ID` | GCP project ID used for authentication |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Workload Identity Federation provider resource name |
| `GCP_SERVICE_ACCOUNT_EMAIL` | Service account email used by GitHub Actions |

> **Note:** `GCP_PROJECT_ID` is the project used for GitHub Actions authentication via Workload Identity Federation. The Dataflow job runs in `dataflow_project` defined in `config.json`, which may be a different project.

---

## Workflow Triggers

The workflow triggers automatically on:

```yaml
# Automatic — any file change under application/dataflow/
on:
  pull_request:
    branches: [ main ]
    paths:    [ 'application/dataflow/**' ]

# Manual — triggered from GitHub Actions UI
  workflow_dispatch:
```

To trigger manually: **GitHub → Actions → Dataflow Template Build → Run workflow**

---

## Deployment Steps

### Step 1 — Plan
- Loads `config.json` and prints the full deployment configuration
- Lists currently running Dataflow jobs for review

### Step 2 — Approval
- Pauses the workflow and waits for a team member to approve
- Configure approvers under **GitHub → Settings → Environments → application**
- The workflow proceeds only after explicit approval

### Step 3 — Build
Performs three actions in sequence:

1. **Docker build** — builds the container image using `Dockerfile`
2. **Docker push** — pushes the image to Google Artifact Registry tagged with `github.run_id`
3. **Flex Template build** — generates the template JSON spec and uploads it to GCS

Each build is tagged with `${{ github.run_id }}` ensuring every deployment is uniquely versioned and traceable.

### Step 4 — Deploy
1. **Validates** the template JSON exists in GCS
2. **Drains** any existing running job with the same name (waits for graceful completion)
3. **Deploys** the new Flex Template job with all parameters from `config.json`
4. **Confirms** the job was launched by listing active Dataflow jobs

---

## Monitoring

### View running Dataflow jobs

```bash
gcloud dataflow jobs list \
  --project=sw-dev-prj-sandbox \
  --region=us-east4 \
  --filter="state=JOB_STATE_RUNNING" \
  --format="table(id, name, currentState, startTime)"
```

### View job logs

```bash
gcloud logging read \
  'resource.type="dataflow_step" AND severity>=ERROR' \
  --project=sw-dev-prj-sandbox \
  --limit=50 \
  --format="value(timestamp, textPayload)"
```



---

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `permission denied: dataflow.jobs.create` | SA missing Dataflow Admin role | Grant `roles/dataflow.admin` to the SA |
| `network not found` | Default VPC deleted or wrong network name | Set correct `network` and `subnetwork` in `config.json` |
| `Missing required parameter` | `metadata.json` param names don't match script args | Ensure `metadata.json` parameter `name` fields match `argparse` argument names in the Python script |
| `Network is unreachable` (pip install) | Workers have no internet access | Pre-install all dependencies in `Dockerfile` |
| `python_template_launcher not found` | Wrong Docker base image | Use `gcr.io/dataflow-templates-base/python311-template-launcher-base` |
| `apache-beam conflict` | Duplicate or incompatible versions in `requirements.txt` | Keep only `apache-beam[gcp]==2.62.0` — it bundles `google-cloud-storage` and `google-cloud-pubsub` |
| `JOB_STATE_FAILED` immediately | Template parameters missing or wrong | Check `--parameters` names match `metadata.json` and Python script exactly |