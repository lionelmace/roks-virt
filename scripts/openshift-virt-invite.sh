#!/bin/sh
# Uncommment to verbose
# set -x 

source ./local.env

ibmcloud login --apikey $APIKEY -r $IBMCLOUD_REGION -g $RESOURCE_GROUP_NAME
# ibmcloud target -r $IBMCLOUD_REGION -g $RESOURCE_GROUP_NAME

export MASTER_URL=$(ibmcloud ks cluster get --cluster $CLUSTER_NAME --json | jq -r .masterURL)
INGRESS_URL=$(ibmcloud ks cluster get --cluster $CLUSTER_NAME --json | jq -r .ingress.hostname)
CLUSTER_ID=$(ibmcloud ks cluster get --cluster $CLUSTER_NAME --json | jq -r .id)
sleep 4
printf "\n## Logging into OpenShift Cluster \"$CLUSTER_NAME\" ...\n"
# oc login -u apikey -p $APIKEY --server=$MASTER_URL --insecure-skip-tls-verify=true
oc login -u apikey -p $APIKEY --server=$MASTER_URL

# --------- BEGIN
enableVirtRoleBinding() {
  # Grants rights to create/manage VMs etc in *that namespace* (once OpenShift Virtualization is installed cluster-wide)
  cat <<EOF | oc apply -f -
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kubevirt-edit
  namespace: $1
subjects:
  - kind: User
    apiGroup: rbac.authorization.k8s.io
    name: IAM#$2
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kubevirt.io:edit
EOF
}
# --------- END

enableProjectResourceQuota() {
  cat <<EOF | oc apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: quota-$1
  namespace: $1
spec:
  hard:
    pods: '4'
    requests.cpu: '1'
    requests.memory: 4Gi
    limits.cpu: '2'
    limits.memory: 8Gi
EOF
}

for email in $EMAIL
do
  # Convert email to lowercase otherwise users with uppercase email cannot see Operator Hub. Weird!
  email=$(echo $email | awk '{print tolower($0)}' )

  ## Extract last name from email and convert to lower case
  lastname=$(echo $email | awk -F'@' '{print $1}' | sed 's?.*\.??g' | sed 's?.*\_??g' )
  project_name="vm-$lastname"

  # Create a new OpenShift project with the last name
  printf "\n## Creating project \"$project_name\".\n"
  oc new-project $project_name

  # Invite user to the Account
  #   printf "\n## Inviting user \"$email\" to the account id \"$ACCOUNT_ID\".\n"
  #   ibmcloud account user-invite $email

  # Invite user to the IAM Access Group
  printf "\n## Inviting user \"$email\" to the Access Group \"$ACCESS_GROUP_NAME\".\n"
  ibmcloud iam access-group-user-add $ACCESS_GROUP_NAME $email

  # Assign IAM User Policy
  printf "\n## Assigning IAM Viewer policy to allow the user to view the cluster in the IBM Cloud Console.\n"
  ibmcloud iam user-policy-create $email --roles Viewer --service-name containers-kubernetes --service-instance $CLUSTER_ID
  
  # Grant admin access on the OpenShift project
  printf "\n## Assigning IAM Writer policy to the user project.\n"
  ibmcloud iam user-policy-create $email --roles Writer --service-name containers-kubernetes --service-instance $CLUSTER_ID --attributes "namespace=$project_name"

  # Add edit role to the user so they can work within the project $project_name
  # Warning: user will only appear in OpenShift once the user has logged at least once
  # iam_email=$(oc get users | grep -i $email | awk '{ print $1}')
  printf "\n## Add Edit role to the user $email so he can work within the project \"$project_name\".\n"
  # oc adm policy add-role-to-user edit IAM#$email -n $project_name
  oc adm policy add-role-to-user admin IAM#$email -n $project_name

  # Add explicit virtualization usage rights (optional but clearer)
  enableVirtRoleBinding $project_name $email
  # enableProjectResourceQuota $project_name

  # # OpenShift Operators ----------------------------
  # Gives visibility to the installed OpenShift Operators
  # cluster-scope read access needed by the ODF console UI. 
  # Warning: Also gives visibility to all projects in the cluster.
  oc adm policy add-cluster-role-to-user view IAM#$email

  # ODF ----------------------------------------------
  # Add visibility to the project hosting the operators Virtualization, ODF
  for ns in openshift-cnv openshift-local-storage openshift-storage openshift-mtv;
    do
      oc adm policy add-role-to-user view IAM#$email -n $ns
  done

  # ODF requires read-only access to monitoring metrics.
  oc adm policy add-cluster-role-to-user cluster-monitoring-view IAM#$email
  # ODF ----------------------------------------------

  # Access has been granted
  printf "\n## Link to access the Cluster Overview in IBM Cloud:\n"
  printf "https://cloud.ibm.com/kubernetes/clusters/$CLUSTER_ID/overview?bss_account=$ACCOUNT_ID"
  printf "\n## Link to access directly the Openshift console:\n"
  # URL to access the OpenShift Console and enter credentials
  # Example: https://console-openshift-console.iro-541970-483cccd2f0d38128dd40d2b711142ba9-0000.eu-de.containers.appdomain.cloud/topology/ns/lab-mace
  echo https://console-openshift-console.$INGRESS_URL

  printf "\n## ----------------------------------------------------\n"
done