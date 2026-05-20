# Preparation for localnet topology

## Create a new Open vSwitch (OVS)

In the Red Hat OpenShift Virtualization worker nodes in IBM Cloud, there is 2nd PCI interface on the worker node. This interface is initially not used. We will create an OVS and use that as its physical uplink to the VPC.

1. Install NMState Operator

1. Create the nmstate instance

    ```sh
    cat <<EOF | oc apply -f -
    apiVersion: nmstate.io/v1
    kind: NMState
    metadata:
      name: nmstate
      namespace: openshift-nmstate
    EOF
    ````

1. Create a new Open vSwitch (OVS)

    ```sh
    cat <<EOF | oc apply -f -
    ---
    apiVersion: nmstate.io/v1
    kind: NodeNetworkConfigurationPolicy
    metadata:
      name: br-vpc
    spec:
      desiredState:
        interfaces:
        - name: br-vpc
          description: A dedicated OVS bridge with a PCI eth1 as a port
          type: ovs-bridge
          state: up
          bridge:
            allow-extra-patch-ports: true
            options:
              stp: false
            port:
              - name: eth1
    EOF
    ```

## Create a bridge-mapping for localnets

When using localnet topology in OVN-Kubernetes, the bridge mapping tells OVN-kubernetes in which physical network to create the CUDN localnet ports. In this case we want it to use the newly created OVS in the previous step.

1. Create a bridge-mapping for localnets

    ```sh
    cat <<EOF | oc apply -f -
    ---
    apiVersion: nmstate.io/v1
    kind: NodeNetworkConfigurationPolicy
    metadata:
      name: vpc-attachment-vlans
    spec:
      desiredState:
        ovn:
        bridge-mappings:
            - localnet: vpc-attachment-vlans
              bridge: br-vpc
              state: present
    EOF
    ```
