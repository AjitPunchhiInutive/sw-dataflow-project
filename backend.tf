terraform {
  backend "gcs" {
    bucket = "itp-terraform-test"
    prefix = "sw-dataflow-project/state"
  }
}
