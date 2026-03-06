# Create a managed OpenShift cluster via CLI

```sh
ibmcloud is vpcc virt-vpc --resource-group-name virtualization
```

```sh
ibmcloud ks cluster create vpc-gen2  \
--name virt-roks  \
--zone eu-de-2  \
--vpc-id r010-0fe0b0ee-6a51-4858-819e-aa1eefe62611  \
--subnet-id 02b7-0e77305a-a522-4fce-be4e-3b37dbafa36f  \
--flavor cx2d.metal.96x192  \
--workers 3  \
--operating-system RHCOS  \
--kube-version 4.20.14_openshift  \
--disable-outbound-traffic-protection  \
--cni OVNKubernetes  \
--cos-instance crn:v1:bluemix:public:cloud-object-storage:global:a/ad09f476263c44cda2cdc697bd808a6f:cb0eb88b-2cfc-48e9-b833-26340218f938::
```
