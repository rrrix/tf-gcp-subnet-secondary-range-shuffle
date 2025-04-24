# Broken GCP Terraform Imported VPC Subnet Secondary Ranges

## Overview

When using multiple `secondary_ip_range` blocks on an imported `google_compute_subnetwork` resource, 
the google-beta provider will attempt to erroneously update the `secondary_ip_range` blocks in an out-of-order fashion.   

Given the terraform input:

```terraform
resource "google_compute_subnetwork" "default" {
  provider                         = google-beta
  # [uninteresting attributes redacted]

  secondary_ip_range {
    range_name              = "gke-pods-1"
    reserved_internal_range = "networkconnectivity.googleapis.com/${google_network_connectivity_internal_range.gke_pods_1.id}"
  }
  secondary_ip_range {
    range_name              = "gke-services-1"
    reserved_internal_range = "networkconnectivity.googleapis.com/${google_network_connectivity_internal_range.gke_services_1.id}"
  }
  secondary_ip_range {
    range_name              = "gke-pods-2"
    reserved_internal_range = "networkconnectivity.googleapis.com/${google_network_connectivity_internal_range.gke_pods_2.id}"
  }
  secondary_ip_range {
    range_name              = "gke-services-2"
    reserved_internal_range = "networkconnectivity.googleapis.com/${google_network_connectivity_internal_range.gke_services_2.id}"
  }
}
```

The `hashicorp/google-beta` provider gets "confused" about the `secondary_ip_range` attributes (that it set itself!) 
and will attempt to update them. 

Between the first and second `terraform apply` runs, the list of `secondary_ip_range` appears to get "shuffled" in an 
unexpected, but _consistent_, manner. 

Below is the result from running a `terraform plan` _immediately after_ a `terraform apply`, without making any changes.

```terminaloutput
  # google_compute_subnetwork.default will be updated in-place
  ~ resource "google_compute_subnetwork" "default" {
        id                               = "projects/tf-test-project/regions/us-central1/subnetworks/tf-test-imported-with-secondary-ranges"
        name                             = "tf-test-imported-with-secondary-ranges"
        # (15 unchanged attributes hidden)

      ~ secondary_ip_range {
          ~ range_name              = "gke-services-2" -> "gke-pods-1"
          ~ reserved_internal_range = "https://networkconnectivity.googleapis.com/v1/projects/tf-test-project/locations/global/internalRanges/gke-services-2" -> "networkconnectivity.googleapis.com/projects/tf-test-project/locations/global/internalRanges/gke-pods-1"
            # (1 unchanged attribute hidden)
        }
      ~ secondary_ip_range {
          ~ range_name              = "gke-pods-1" -> "gke-pods-2"
          ~ reserved_internal_range = "https://networkconnectivity.googleapis.com/v1/projects/tf-test-project/locations/global/internalRanges/gke-pods-1" -> "networkconnectivity.googleapis.com/projects/tf-test-project/locations/global/internalRanges/gke-pods-2"
            # (1 unchanged attribute hidden)
        }
      ~ secondary_ip_range {
          ~ range_name              = "gke-pods-2" -> "gke-services-2"
          ~ reserved_internal_range = "https://networkconnectivity.googleapis.com/v1/projects/tf-test-project/locations/global/internalRanges/gke-pods-2" -> "networkconnectivity.googleapis.com/projects/tf-test-project/locations/global/internalRanges/gke-services-2"
            # (1 unchanged attribute hidden)
        }

        # (1 unchanged block hidden)
    }
```

The order of steps to reproduce this:

* Create a Google Compute Network resource _outside the current terraform module_
* Create a Google Compute Subnetwork resource _outside the current terraform module_
* Import the Network and Subnetwork into terraform state
* Terraform Plan
* Terraform Apply (updates the `subnetwork.secondaryIpRanges` field)
* Terraform Plan (observe problem here)
  * Don't make _any_ changes!
* Terraform Apply... 💥

NOTE: We are only able to reproduce this problem when using an _imported_ `google_compute_subnetwork` resource. 
At our organization, a dedicated team provisions our VPC with a specific subnet primary IP CIDR, along with Cloud VPN, routes, etc.
The VPC and subnet (without secondary ranges) is created outside of Terraform, but we want to manage the secondary ranges with terraform
for subsequent use with GKE (also managed via terraform).

## Steps to reproduce

### Prerequisites

1. A Google Cloud Project with proper billing setup and Compute Engine APIs enabled.
2. Valid credentials to access your GCP project with the ability to create/list/delete Networks, Subnetworks, and Reserved IP Ranges.
3. (Optional) `google-cloud-sdk` a.k.a. `gcloud` installed and available on your `$PATH`

### Setup Terraform, VPC and Subnet

Initialize the root module:

```shell
terraform init
```

Set the required variable `TF_VAR_project_id`

```shell
export TF_VAR_project_id=YOUR_GOOGLE_CLOUD_PROJECT_ID 
```

(Optional) Set other optional variables:

```shell
# NOTE: These values are alredy set in terraform.tfvars.json
export TF_VAR_region=us-central1
export TF_VAR_network_name=tf-test-tmp
export TF_VAR_subnet_name=tf-test-tmp-imported-with-secondary-ranges
```

Create the VPC and Subnet using the given shell script

NOTE: Optional if you want to create your VPC and subnet another way. 

```shell
./create_vpc_and_subnet.sh
```

### Terraform: Import, Plan, Apply, Plan

After setting your required variables, import the VPC and Subnet:

```shell
./import_vpc_and_subnet.sh
```

Create and review a plan:

```shell
terraform plan -out=plan.tfplan
```

Apply the plan:

```shell
terraform apply plan.tfplan
```

IMPORTANT: Create another plan. This will reproduce the problem.

```shell
terraform plan -out=plan.tfplan
```

<details>
<summary>
Expand to view example output showing shuffled <code>secondary_ip_range</code> blocks
</summary>


```terminaloutput
  # google_compute_subnetwork.default will be updated in-place
  ~ resource "google_compute_subnetwork" "default" {
        id                               = "projects/tf-test-project/regions/us-central1/subnetworks/tf-test-tmp-imported-with-secondary-ranges"
        name                             = "tf-test-tmp-imported-with-secondary-ranges"
        # (15 unchanged attributes hidden)

      ~ secondary_ip_range {
          ~ range_name              = "gke-services-2" -> "gke-pods-1"
          ~ reserved_internal_range = "https://networkconnectivity.googleapis.com/v1/projects/tf-test-project/locations/global/internalRanges/gke-services-2" -> "networkconnectivity.googleapis.com/projects/tf-test-project/locations/global/internalRanges/gke-pods-1"
            # (1 unchanged attribute hidden)
        }
      ~ secondary_ip_range {
          ~ range_name              = "gke-pods-1" -> "gke-pods-2"
          ~ reserved_internal_range = "https://networkconnectivity.googleapis.com/v1/projects/tf-test-project/locations/global/internalRanges/gke-pods-1" -> "networkconnectivity.googleapis.com/projects/tf-test-project/locations/global/internalRanges/gke-pods-2"
            # (1 unchanged attribute hidden)
        }
      ~ secondary_ip_range {
          ~ range_name              = "gke-pods-2" -> "gke-services-2"
          ~ reserved_internal_range = "https://networkconnectivity.googleapis.com/v1/projects/tf-test-project/locations/global/internalRanges/gke-pods-2" -> "networkconnectivity.googleapis.com/projects/tf-test-project/locations/global/internalRanges/gke-services-2"
            # (1 unchanged attribute hidden)
        }

        # (1 unchanged block hidden)
    }
```

</details>

TIP: You won't be able to `terraform apply` this plan - it will fail with an HTTP 400, as you can't re-arrange 
secondary IP ranges on an subnetwork.

```shell
# This will fail
terraform apply plan.tfplan
```

<details>
<summary>Expand to view failed apply</summary>


```terminaloutput
$ tofu apply -auto-approve plan.tfplan
google_compute_subnetwork.default: Modifying... [id=projects/tf-test-project/regions/us-central1/subnetworks/tf-test-tmp-imported-with-secondary-ranges]
╷
│ Error: Error updating Subnetwork "projects/tf-test-project/regions/us-central1/subnetworks/tf-test-tmp-imported-with-secondary-ranges": googleapi: Error 400: Invalid value for field 'resource.secondaryIpRanges[0].ipCidrRange': '10.2.144.0/20'. Existing secondary range cannot be modified: 10.2.144.0/20., invalid
│
│   with google_compute_subnetwork.default,
│   on main.tf line 65, in resource "google_compute_subnetwork" "default":
│   65: resource "google_compute_subnetwork" "default" {
│
╵
```


</details>

## Rinse, Repeat

If you want to test this again (and again, and again... like I did), use the 
`abandon_vpc_and_subnet.sh` and `import_vpc_and_subnet.sh` helper scripts to make it easy.

This will:
  * Remove the `google_compute_network.default` resource from terraform state
  * Remove the `google_compute_subnetwork.default` resource from terraform state
  * Use `gcloud` to update the subnet, removing the `secondaryIpRanges` that were set via terraform
  * Re-import the network and subnetwork into terraform state

```shell
./abandon_vpc_and_subnet.sh
./import_vpc_and_subnet.sh
```

Then follow the steps in [Terraform: Import, Plan, Apply, Plan](#terraform-import-plan-apply-plan)
