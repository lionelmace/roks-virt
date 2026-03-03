# ODF Troubleshooting commands

Below is a list of troubleshooting commands when installing and updating ODF.

## Table of content

1. [Check the ODF cluster](#check-the-odf-cluster)
1. [Check the logs of OCS operator controller manager](#check-the-logs-of-ocs-operator-controller-manager)
1. [Check the logs of metric agent](#check-the-logs-of-metric-agent)
1. [Change worker name assigned to ODF](#change-worker-name-assigned-to-odf)
1. [Control the managed addon option of ocs](#control-the-managed-addon-option-of-ocs)
1. [Check the disk available in the storage node](#check-the-disk-available-in-the-storage-node)

## Check the ODF cluster

1. Get the ODF cluster

    ```sh
    oc get storagecluster -n openshift-storage
    ```

1. Describe ODF cluster

    ```sh
    oc describe storagecluster <name> -n openshift-storage
    ```

    Exemple:

    ```sh
    oc describe storagecluster ocs-storagecluster -n openshift-storage
    ```

## Check the logs of OCS operator controller manager

1. Get OCS pod name

    ```sh
    export POD_OCS_NAME=$(oc get pods -n kube-system | grep ocs | awk '{print $1}')
    ```

1. Get the logs of OCS operator controller manager

    ```sh
    oc logs -n kube-system $POD_OCS_NAME
    ```

    > If the ODF operator has been successfully installed, you will see the message:
    "msg":"OcsCluster is successful and ready!!!"

## Check the logs of metric agent

1. Make sure the metric agent is running.

    ```sh
    oc get pods -n kube-system | grep metrics
    ```

1. If the metric agent is running, save the pod metric agent name.

    ```sh
    export POD_METRIC_NAME=$(oc get pods -n kube-system | grep metrics | awk '{print $1}')
    ```

1. If the agent is running, get it logs

    ```sh
    oc logs -n kube-system $POD_METRIC_NAME
    ```

## Change worker name assigned to ODF

1. Get the worker names

    ```sh
    oc get nodes
    ```

1. Change the names of the worker assigned to ODF

    ```sh
    ibmcloud sat storage config param set --config <your_storage_config_name> --param "worker-nodes=<node-name-1>,<node-name-2>,<node-name-3>" --apply
    ```

    Example:

    ```sh
    ibmcloud sat storage config param set --config vmware-odf-local-storage --param "worker-nodes=satellite-270002r30a-pc7rcizz-storage-0.csplab.local,satellite-270002r30a-pc7rcizz-storage-1.csplab.local,satellite-270002r30a-pc7rcizz-storage-2.csplab.local" --apply
    ```

## Control the managed addon option of ocs

1. Get the status of managed-addon-options-osc

    ```sh
    oc describe cm managed-addon-options-osc -n kube-system
    ```

## Check the disk available in the storage node

1. Connect to the storage node.

    ```sh
    oc get nodes
    oc debug node/<worker-node-name>
    ```

1. List block devices

    ```sh
    lsblk
    ```

1. List block devices with output info  about  filesystems

    ```sh
    lsblk -f
    ```

    > You will be able to see the 8 nvme disks
            8:5    0   1.3M  0 part
        nbd0   43:0    0     0B  0 disk
        nbd1   43:32   0     0B  0 disk
        nbd2   43:64   0     0B  0 disk
        nbd3   43:96   0     0B  0 disk
        nbd4   43:128  0     0B  0 disk
        nbd5   43:160  0     0B  0 disk
        nbd6   43:192  0     0B  0 disk
        nbd7   43:224  0     0B  0 disk
        nvme5n1
            259:0    0   2.9T  0 disk
        nvme7n1
            259:1    0   2.9T  0 disk
        nvme0n1
            259:2    0   2.9T  0 disk
        nvme2n1
            259:3    0   2.9T  0 disk
        nvme4n1
            259:4    0   2.9T  0 disk
        nvme3n1
            259:5    0   2.9T  0 disk
        nvme6n1
            259:6    0   2.9T  0 disk
        nvme1n1
            259:7    0   2.9T  0 disk
        nbd8   43:256  0     0B  0 disk
        nbd9   43:288  0     0B  0 disk
        nbd10  43:320  0     0B  0 disk
        nbd11  43:352  0     0B  0 disk
        nbd12  43:384  0     0B  0 disk
        nbd13  43:416  0     0B  0 disk
        nbd14  43:448  0     0B  0 disk
        nbd15  43:480  0     0B  0 disk
