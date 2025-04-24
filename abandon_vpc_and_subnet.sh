#!/bin/bash

set -o nounset -o errexit -o pipefail -o xtrace

# Allow environment override for terraform binary, e.g.: tf=/path/to/terraform
: tf=${tf:=terraform}

if command -v jq &>/dev/null; then
  if [[ -z "$TF_VAR_region" ]]; then
    TF_VAR_region=$(jq -r .region terraform.tfvars.json)
    export TF_VAR_region
  fi
  if [[ -z "$TF_VAR_network_name" ]]; then
    TF_VAR_network_name=$(jq -r .network_name terraform.tfvars.json)
  fi
  if [[ -z "$TF_VAR_subnet_name" ]]; then
    TF_VAR_subnet_name=$(jq -r .subnet_name terraform.tfvars.json)
  fi
fi

# Set a default region
: ${TF_VAR_region:="us-central1"}
export TF_VAR_region

# VPC Name
: ${TF_VAR_network_name:="tf-test-tmp"}
export TF_VAR_network_name
# Subnet Name
: ${TF_VAR_subnet_name:="tf-test-tmp-imported-with-secondary-ranges"}
export TF_VAR_subnet_name

$tf state rm google_compute_network.default
$tf state rm google_compute_subnetwork.default

secondary_ranges=$(echo gke-{pods,services}-{1,2} | tr " " ",")

gcloud compute networks subnets update ${TF_VAR_subnet_name} \
  --project=${TF_VAR_project_id} \
  --region=${TF_VAR_region} \
  --remove-secondary-ranges=${secondary_ranges}
