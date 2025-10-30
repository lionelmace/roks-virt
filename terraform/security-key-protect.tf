
########################################################################################################################
# Key Protect
########################################################################################################################

locals {
  key_ring        = "ocp"
  cluster_key     = "${var.prefix}-cluster-data-encryption-key"
  boot_volume_key = "${var.prefix}-boot-volume-encryption-key"
}

module "kp_all_inclusive" {
  source                    = "terraform-ibm-modules/kms-all-inclusive/ibm"
  version                   = "5.4.3"
  key_protect_instance_name = "${var.prefix}-kp-instance"
  resource_group_id         = module.resource_group.resource_group_id
  region                    = var.region
  resource_tags             = var.resource_tags
  keys = [{
    key_ring_name = local.key_ring
    keys = [
      {
        key_name     = local.cluster_key
        force_delete = true
      },
      {
        key_name     = local.boot_volume_key
        force_delete = true
      }
    ]
  }]
}