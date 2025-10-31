########################################################################################################################
# Variables
########################################################################################################################
variable "ocp_version" {
  type        = string
  description = "Version of the OCP cluster to provision"
  default     = null
}

variable "ocp_entitlement" {
  type        = string
  description = "Value that is applied to the entitlements for OCP cluster provisioning"
  default     = null
}

variable "enable_openshift_version_upgrade" {
  type        = bool
  description = "When set to true, allows Terraform to manage major OpenShift version upgrades. This is intended for advanced users who manually control major version upgrades. Defaults to false to avoid unintended drift from IBM-managed patch updates. NOTE: Enabling this on existing clusters requires a one-time terraform state migration. See [README](https://github.com/terraform-ibm-modules/terraform-ibm-base-ocp-vpc/blob/main/README.md#openshift-version-upgrade) for details."
  default     = false
}

variable "disable_outbound_traffic_protection" {
  type        = bool
  description = "When set to true, enabled outbound traffic."
  default     = false
}

variable "default_worker_pool_machine_type" {
  type        = string
  description = "The machine type for the default worker pool"
  default     = "bx2.4x16"
}

variable "workers_per_zone" {
  type        = number
  description = "The number of workers per zone"
  default     = 1
}

variable "excluded_zones" {
  description = "List of zones to exclude from the dynamic zone assignment"
  type        = list(string)
}


########################################################################################################################
# 3 zone OCP VPC cluster
########################################################################################################################

locals {

  # Get all subnets from the VPC module
  all_subnets = module.vpc.subnet_zone_list

  # Define subnets for the default worker pool (across 3 zones)
  subnets = [
    for subnet in local.all_subnets :
    {
      id         = subnet.id
      zone       = subnet.zone
      cidr_block = subnet.cidr
    }
    if !contains(var.excluded_zones, subnet.zone)
  ]

  # mapping of cluster worker pool names to subnets
  cluster_vpc_subnets = {
    zone-1 = local.subnets,
    zone-2 = local.subnets,
    zone-3 = local.subnets
  }

  boot_volume_encryption_kms_config = {
    crk             = module.kp_all_inclusive.keys["${local.key_ring}.${local.boot_volume_key}"].key_id
    kms_instance_id = module.kp_all_inclusive.kms_guid
  }

  worker_pools = [
    {
      subnet_prefix                     = "zone-1"
      pool_name                         = "default" # ibm_container_vpc_cluster automatically names default pool "default" (See https://github.com/IBM-Cloud/terraform-provider-ibm/issues/2849)
      machine_type                      = "bx2.16x64"
      workers_per_zone                  = 1
      operating_system                  = "RHCOS"
      boot_volume_encryption_kms_config = local.boot_volume_encryption_kms_config
    },
    # {
    #   subnet_prefix                     = "zone-2"
    #   pool_name                         = "zone-2"
    #   machine_type                      = "bx2.16x64"
    #   workers_per_zone                  = 1
    #   secondary_storage                 = "300gb.5iops-tier"
    #   operating_system                  = "RHCOS"
    #   boot_volume_encryption_kms_config = local.boot_volume_encryption_kms_config
    # }
  ]

  worker_pools_taints = {
    all     = []
    default = []
    zone-2 = [{
      key    = "dedicated"
      value  = "zone-2"
      effect = "NoExecute"
    }]
    zone-3 = [{
      key    = "dedicated"
      value  = "zone-3"
      effect = "NoExecute"
    }]
  }
}

module "ocp_base" {
  source = "terraform-ibm-modules/base-ocp-vpc/ibm"

  cluster_name                        = var.prefix
  resource_group_id                   = module.resource_group.resource_group_id
  region                              = var.region
  force_delete_storage                = true
  vpc_id                              = module.vpc.vpc_id
  vpc_subnets                         = local.cluster_vpc_subnets
  worker_pools                        = local.worker_pools
  ocp_version                         = var.ocp_version
  tags                                = var.resource_tags
  access_tags                         = var.access_tags
  worker_pools_taints                 = local.worker_pools_taints
  ocp_entitlement                     = var.ocp_entitlement
  enable_openshift_version_upgrade    = var.enable_openshift_version_upgrade
  disable_outbound_traffic_protection = var.disable_outbound_traffic_protection
  # Set to folse as local-exec is not supported by default on Terraform Cloud
  verify_worker_network_readiness     = false
  addons = {
    # "cluster-autoscaler"  = { version = "1.2.3" }
    # "vpc-file-csi-driver" = { version = "2.0" }  # 2.0 will enable latest driver version such as 2.0.16
  }
  kms_config = {
    instance_id = module.kp_all_inclusive.kms_guid
    crk_id      = module.kp_all_inclusive.keys["${local.key_ring}.${local.cluster_key}"].key_id
  }
}

data "ibm_container_cluster_config" "cluster_config" {
  cluster_name_id   = module.ocp_base.cluster_id
  resource_group_id = module.ocp_base.resource_group_id
  #LMA config_dir        = "${path.module}/../../kubeconfig"
}

########################################################################################################################
# Kube Audit
# Needs to be commented if used in Terraform Cloud as local-exec not supported by default
########################################################################################################################

# module "kube_audit" {
#   depends_on                = [module.ocp_base] # Wait for the cluster to completely deploy.
#   source                    = "terraform-ibm-modules/base-ocp-vpc/ibm//modules/kube-audit"
#   cluster_id                = module.ocp_base.cluster_id
#   cluster_resource_group_id = module.resource_group.resource_group_id
#   audit_log_policy          = "WriteRequestBodies"
#   region                    = var.region
#   ibmcloud_api_key          = var.ibmcloud_api_key
# }