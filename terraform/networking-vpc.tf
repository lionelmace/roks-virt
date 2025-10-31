########################################################################################################################
# VPC + Subnets + Public Gateways using landing-zone-vpc module
########################################################################################################################

module "vpc" {
  source = "terraform-ibm-modules/landing-zone-vpc/ibm"
  # version           = "8.8.0"
  resource_group_id = module.resource_group.resource_group_id
  region            = var.region
  prefix            = var.prefix
  tags              = var.resource_tags
  name              = "${var.prefix}-vpc"

  # Define subnets across 3 zones for the default worker pool
  subnets = {
    zone-1 = [
      {
        name           = "subnet-default-1"
        cidr           = "10.10.10.0/24"
        public_gateway = true
        acl_name       = "vpc-acl"
      }
    ],
    zone-2 = [
      {
        name           = "subnet-default-2"
        cidr           = "10.20.10.0/24"
        public_gateway = true
        acl_name       = "vpc-acl"
      }
    ],
    zone-3 = [
      {
        name           = "subnet-default-3"
        cidr           = "10.30.10.0/24"
        public_gateway = true
        acl_name       = "vpc-acl"
      }
    ]
  }

  # Enable public gateways in all zones
  use_public_gateways = {
    zone-1 = true
    zone-2 = true
    zone-3 = true
  }

  # Define network ACLs
  network_acls = [
    {
      name                         = "vpc-acl"
      add_ibm_cloud_internal_rules = true
      add_vpc_connectivity_rules   = true
      rules                        = []
    }
  ]
}
