##############################################################################
## Global Variables
##############################################################################

prefix = "virt"
region = "ca-tor"

##############################################################################
## Module OCP VPC
##############################################################################
ocp_version                         = "4.19"
disable_outbound_traffic_protection = true
default_worker_pool_machine_type    = "bx2.4x16"
# Bare Metal Profile, run command `ibmcloud is bm-prs`
# BM Profile only available in Toronto MZR:
# cx2d.metal.96x192, bx2d.metal.96x384, mx2d.metal.96x768

# Skip zones if insufficient capacity within those zones
excluded_zones = ["ca-tor-1", "ca-tor-3"]
# Set the worker_count to 2 to comply with minimum worker per cluster if 2 zones are excluded.
workers_per_zone = 2
