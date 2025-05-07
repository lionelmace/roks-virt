#!/bin/bash

set -exuo pipefail

cd $(dirname $BASH_SOURCE)

DEPLOY_NAMESPACE=${DEPLOY_NAMESPACE:-none}

if [[ ${DEPLOY_NAMESPACE} == "none" ]]
then
    echo "Unable to determine which Namespace the image deployment should be done on. Please ensure the environment variable DEPLOY_NAMESPACE is specified."
    exit 1
fi

#oc project "${DEPLOY_NAMESPACE}"

OPENSHIFT_IMAGE_PULL_SECRET=$(oc extract secret/`oc get sa/default -n ${DEPLOY_NAMESPACE} -o yaml | grep default-dockercfg | cut -c 9- | head -1` --to=- --keys=.dockercfg -n ${DEPLOY_NAMESPACE} | jq  -r '.["image-registry.openshift-image-registry.svc.cluster.local:5000"].password')

cat << EOF | oc apply -n ${DEPLOY_NAMESPACE} -f -
apiVersion: v1
kind: Secret
metadata:
  name: internal-reg-pull-secret
  labels:
    app: containerized-data-importer
type: Opaque
stringData:
  accessKeyId: "$(echo -n 'serviceaccount')"
  secretKey: "$(echo -n $OPENSHIFT_IMAGE_PULL_SECRET)"
EOF