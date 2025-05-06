##############################################################################
# IBM Cloud Provider
##############################################################################

terraform {
  required_version = ">=1.10"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.78.0"
    }
    http-full = {
      source  = "salrashid123/http-full"
      version = "1.3.1"
    }
  }
}

provider "http-full" {}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}

provider "kubernetes" {
  host                   = data.ibm_container_cluster_config.roks_cluster_config.host
  token                  = data.ibm_container_cluster_config.roks_cluster_config.token
  cluster_ca_certificate = base64decode(data.ibm_container_cluster_config.roks_cluster_config.ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.ibm_container_cluster_config.roks_cluster_config.host
    token                  = data.ibm_container_cluster_config.roks_cluster_config.token
    cluster_ca_certificate = base64decode(data.ibm_container_cluster_config.roks_cluster_config.ca_certificate)
  }
}

# Init cluster config for helm and kubernetes providers
############################################################################
data "ibm_container_cluster_config" "roks_cluster_config" {
  cluster_name_id   = ibm_container_vpc_cluster.roks_cluster.id
  resource_group_id = ibm_resource_group.group.id
  endpoint_type     = "private"
}

# Helm to install IBM Cloud Logs
# Temporary Removed
##############################################################################
# provider "helm" {
#   # alias = "logs"
#   kubernetes {
#     host                   = data.ibm_container_cluster_config.roks_cluster_config.host
#     token                  = data.ibm_container_cluster_config.roks_cluster_config.token
#     cluster_ca_certificate = data.ibm_container_cluster_config.roks_cluster_config.ca_certificate
#   }
#   # IBM Cloud credentials are required to authenticate to the helm repo
#   registry {
#     url      = "oci://icr.io/ibm/observe/logs-agent-helm"
#     username = "iamapikey"
#     password = var.ibmcloud_api_key
#   }
# }