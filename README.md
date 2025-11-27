# Run Virtual Machine on OpenShift on IBM Cloud

> Estimated duration: 2 hours

First, you will provision a ROKS cluster with Bare metal workers.

Then, you will install the OpenShift Virtualization operator.

Finally, you will deploy two types of VMs:

* a stateless VM with a ContainerDisk, which is ephemeral storage. The basic steps here would be to create a container image and use it as the root disk for the Virtual Machine. The OpenShift's internal registry is used to store the container image.
* a stateful the VM with Persistent Volumes (PVs).

![Operator OSV welcome](./images/operator-osv-welcome.png)

## Pre-Requisites

    * terraform
    * docker or podman
    * virtctl
    * OC command line

## Provision the cluster via Terraform

> Estimated duration: 1 hour

The Terraform scripts will provision a 4.19 ROKS clusters with two Bare metal worker nodes in the region Toronto.

1. Set the region, the prefix, the OpenShift version in the file `testing.auto.tfvars`

    > Some MZR (MZR) may have insufficient infrastructure capacity. Should it happen, modify the variable *excluded_zones*.

1. Provision the required infrastructure using the Terraform scripts locally or in Schematics within the IBM Cloud Console.

    ```sh
    cd terraform
    terraform init
    terraform apply
    ```

## Install the OpenShift Virtualization Operator

1. Install the operator from the OperatorHub

    ![Operator OSV](./images/operator-osv.png)

    ![Operator OSV install](./images/operator-osv-install.png)

    ![Operator OSV welcome](./images/operator-osv-welcome.png)

## Connect to the cluster

1. Connect to the cluster

    ```sh
    oc login --token=<ton_token> --server=https://<url_de_ton_cluster>
    ```

1. Create a new project

    ```sh
    export DEPLOY_NAMESPACE=vm-project

    oc new-project $DEPLOY_NAMESPACE
    oc project $DEPLOY_NAMESPACE
    ```

1. Expose the Openshift Internal Image Registry

    ```sh
    oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
    oc get routes -n openshift-image-registry
    OPENSHIFT_REGISTRY=$(oc get routes -n openshift-image-registry | grep default-route-openshift-image-registry | awk '{print $2}')
    ```

1. Login to the OpenShift Registry

    ```sh
    podman login -u kubeadmin -p `oc whoami -t` $OPENSHIFT_REGISTRY
    ````

## Import Image to the OpenShift Registry

1. Download image

    ```sh
    curl -LO https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2
    ```

1. Create Dockerfile

    ```sh
    cat << END > Dockerfile
    FROM kubevirt/container-disk-v1alpha
    ADD Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2 /disk
    END
    ```

1. Build the image

    ```sh
    podman build -t $OPENSHIFT_REGISTRY/$DEPLOY_NAMESPACE/virt-fedora:32 .
    ```

1. Push the image

    ```sh
    podman push $OPENSHIFT_REGISTRY/$DEPLOY_NAMESPACE/virt-fedora:32
    ```

1. Verify the image is uploaded to the registry under the namespace

    ```sh
    oc get is
    oc describe is virt-fedora
    ```

1. Delete the local image

    ```sh
    rm Fedora-Cloud-Base-32-1.6.x86_64.qcow2
    ```

## Provision a stateless VM

1. Provision a VM

    ```sh
    cat <<EOF | oc apply -n $DEPLOY_NAMESPACE -f -
    apiVersion: kubevirt.io/v1
    kind: VirtualMachine
    metadata:
      name: fedora-stateless
      labels:
        app: fedora-stateless
    spec:
      runStrategy: Always # VM starts automatically and restarts if stopped
      template:
        spec:
          domain:
            cpu:
              cores: 1
              sockets: 1
              threads: 1
            devices:
              disks:
                - bootOrder: 1
                  disk:
                    bus: virtio
                  name: rootdisk
                - bootOrder: 4
                  disk:
                    bus: virtio
                  name: cloudinitdisk
              interfaces:
                - bootOrder: 2
                  masquerade: {}
                  model: virtio
                  name: nic0
              networkInterfaceMultiqueue: true
              rng: {}
            machine:
              type: pc-q35-rhel8.1.0
            resources:
              requests:
                memory: 2Gi
          evictionStrategy: LiveMigrate
          hostname: fedora-stateless
          networks:
            - name: nic0
              pod: {}
          terminationGracePeriodSeconds: 0
          volumes:
            - containerDisk:
                image: 'image-registry.openshift-image-registry.svc.cluster.local:5000/$DEPLOY_NAMESPACE/virt-fedora:32'
                imagePullPolicy: Always
              name: rootdisk
            - cloudInitNoCloud:
                userData: |
                  #cloud-config
                  ssh_pwauth: True
                  chpasswd:
                    list: |
                      root:password
                    expire: False
                  hostname: fedora-stateless
              name: cloudinitdisk
    EOF
    ```

1. Navigate to Openshift Console → Virtualization → VirtualMachines.

1. Notice the new Virtual Machine been created and in Running state.

    ![Fedora VM](./images/osv-vm-fedora-running.png)

1. Click on fedora-stateless → VNC Console. Login with credentials as: Username: root Password: password

## Provision a stateful VM

1. Retrieve and store the StorageClass name in a variable

    ```sh
    oc get sc

1. Let's use the default storage class

    ```sh
    STORAGE_CLASS_NAME=ibmc-vpc-block-10iops-tier
    ```

1. Create an Image Pull Secret so that the Containerized Data Importer(CDI) can authenticate itself against the internal registry and pull the image to create a DataVolume out of it. The secret is essentially the default service account image pull secret token which is meant for registry authentication.

    ```sh
    ./generate_image_pull_secret.sh
    ```

1. Apply the VirtualMachine manifest

    ```sh
    cat <<EOF | oc apply -f -
    apiVersion: kubevirt.io/v1
    kind: VirtualMachine
    metadata:
      name: fedora-dv
      labels:
        app: fedora-dv
    spec:
      dataVolumeTemplates:
        - apiVersion: cdi.kubevirt.io/v1
          kind: DataVolume
          metadata:
            name: fedora-dv-disk-0
          spec:
            pvc:
              accessModes:
                - ReadWriteOnce
              resources:
                requests:
                  storage: 50G
              storageClassName: $STORAGE_CLASS_NAME
            source:
              registry:
                url: "docker://image-registry.openshift-image-registry.svc:5000/$DEPLOY_NAMESPACE/virt-fedora:32"
                secretRef: "internal-reg-pull-secret"
      running: true
      template:
        metadata:
          labels:
            kubevirt.io/vm: vm-datavolume
        spec:
          domain:
            cpu:
              cores: 1
              sockets: 1
              threads: 1
            devices:
              disks:
                - bootOrder: 1
                  disk:
                    bus: virtio
                  name: disk-0
                - disk:
                    bus: virtio
                  name: cloudinitdisk
              interfaces:
                - bootOrder: 2
                  masquerade: {}
                  model: virtio
                  name: nic0
              networkInterfaceMultiqueue: true
              rng: {}
            machine:
              type: pc-q35-rhel8.2.0
            resources:
              requests:
                memory: 4Gi
          evictionStrategy: LiveMigrate
          hostname: fedora-pvc
          networks:
            - name: nic0
              pod: {}
          terminationGracePeriodSeconds: 0
          volumes:
            - dataVolume:
                name: fedora-dv-disk-0
              name: disk-0
            - cloudInitNoCloud:
                userData: |
                  #cloud-config
                  ssh_pwauth: True
                  chpasswd:
                    list: |
                      root:password
                    expire: False
                  hostname: fedora-dv
              name: cloudinitdisk
    EOF
    ```

1. Navigate to Openshift Console → Virtualization → VirtualMachines.

1. Notice the new Virtual Machine been created and in **Provisioning** state.

    ![Fedora VM](./images/osv-vm-fedora-running.png)

1. Click on fedora-stateless → VNC Console. Login with credentials as: Username: root Password: password

## Access the Virtual Machine via the cli (oc and virtctl)

1. Switch the context to the deployed namespace

    ```sh
    oc project -n $DEPLOY_NAMESPACE
    ```

1. List the Virtual Machines

    ```sh
    oc get vms
    ```

    Output

    ```sh
    NAME            AGE     VOLUME
    fedora-stateless   9m23s
    ```

1. List the Virtual Machine Instances

    ```sh
    oc get vmis
    ```

    Output

    ```sh
    NAME            AGE   PHASE     IP              NODENAME                                             READY
    fedora-stateless   12m   Running   172.17.57.108   kube-d0criacr0g0gtjirqeb0-osvroks-default-0000024f   True
    ```

1. Access the virtual machine instance via the virtctl cli. Use the credentials as root / password

    ```sh
    virtctl console fedora-stateless
    ```

    Output

    ```sh
    Successfully connected to fedora-stateless console. The escape sequence is ^]

    fedora-stateless login: root
    Password:
    Last login: Tue May 06 16:11:23 on tty1
    [root@fedora-stateless ~]#
    ```

## Clean up the VM and the infrastructure

1. Delete the Virtual Machine

    ```sh
    oc delete vm/fedora-stateless
    ```

1. Delete the infrastructure

    ```sh
    terraform destroy
    ```
