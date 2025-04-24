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

$tf import google_compute_network.default projects/${TF_VAR_project_id}/global/networks/${TF_VAR_network_name}
$tf import google_compute_subnetwork.default projects/${TF_VAR_project_id}/regions/${TF_VAR_region}/subnetworks/${TF_VAR_subnet_name}
