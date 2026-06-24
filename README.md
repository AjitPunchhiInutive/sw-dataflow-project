
## Overview a

bootstrap layer sets up the GCP organization-level primitives required before any workload infrastructure is deployed. This includes:

---



---

## Prerequisites                ssssss



edfefe
- **Terraform** >= 1.6.3.1.1
- **GCP Project** with billing enabled
- **GCS Bucket** for remote state storage
- **Service Account** with permission to impersonate for state backend access (see `backend.tf`)
- SSH access to the private form modules repository (`-sw-prod-udp-rds-infra-modules`)

---

## Configuration

### Variables (`RepoName.tfvars`)

| Variable          | Description                                      | Example                      |
|-------------------|--------------------------------------------------|------------------------------|
| `bucket_name`     | GCS bucket for Terraform remote state            | `Bucket_name`         |
| `gcp_project`     | GCP project ID to deploy resources into          | `Automation Project ID`     |
| `region`          | GCP region                                       | `us`                         |
| `zone`            | GCP zone                                         | `us-east4-a`                 |
| `organization_id` | GCP organization ID                              | `Organization-ID`               |

