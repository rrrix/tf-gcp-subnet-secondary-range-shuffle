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

errors=0

if ! command -v gcloud &>/dev/null; then
  echo "Missing google-cloud-sdk (gcloud) command line tools" 1>&2
  errors=1
fi

if [[ -n "${1:-}" ]]; then
  export TF_VAR_project_id=$1
  export CLOUDSDK_CORE_PROJECT=$1
  shift
elif [[ -n "${TF_VAR_project_id:-}" ]]; then
  export CLOUDSDK_CORE_PROJECT=${TF_VAR_project_id}
elif gcloud config get core/project --quiet &>/dev/null; then
  TF_VAR_project_id=$(gcloud config get core/project --quiet 2>/dev/null)
else
  echo "ERROR: Missing TF_VAR_project_id environment variable" 1>&2
  errors=1
fi

if [[ $errors -gt 0 ]]; then
  exit 1
fi
export TF_VAR_project_id

gcloud compute networks create ${TF_VAR_network_name} \
  --project=${TF_VAR_project_id} \
  --bgp-routing-mode=global \
  --subnet-mode=custom \
  --quiet \
  --verbosity=error \
  "$@"

gcloud compute networks subnets create \
  ${TF_VAR_subnet_name} \
  --project=${TF_VAR_project_id} \
  --network=${TF_VAR_network_name} \
  --region=${TF_VAR_region} \
  --purpose=PRIVATE    \
  --enable-private-ip-google-access \
  --range="10.1.0.0/16" \
  --quiet \
  --verbosity=error \
   "$@"
