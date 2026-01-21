## Generating an API Key by using the CLI

Complete the following steps to generate an API key for a service ID by using the CLI:

Log in to your IBM Cloud account.

1. Create a service ID that is used for the IAM policies and API key credentials.

    ```sh
    ibmcloud iam service-id-create logs-svc-id --description "Service ID for IBM Cloud Logs"
    ```

1. Add an IAM policy for your service ID that grants access to send logs.

    ```sh
    ibmcloud iam service-policy-create <SERVICE_ID> --service-name logs --roles Sender
    ```sh

1. Create an API key for the service ID.

    ```sh
    ibmcloud iam service-api-key-create logs-ingestion-key <SERVICE_ID> --description "API key for service ID <SERVICE_ID> with permissions to send logs to the IBM Cloud Logs service"
    ```

## Download the required RPM or DEB packages

curl -LO https://logs-router-agent-install-packages.s3.us.cloud-object-storage.appdomain.cloud/logs-router-agent-rhel8-1.7.0.rpm
curl -LO https://logs-router-agent-install-packages.s3.us.cloud-object-storage.appdomain.cloud/logs-router-agent-rhel8-1.7.0.rpm.sha256

## Set up and deploy the Logging agent configuration

rpm -ivh logs-router-agent-rhel8-1.7.0.rpm

## Resources

* [Deploying the Logging agent for Linux](https://cloud.ibm.com/docs/cloud-logs?topic=cloud-logs-agent-linux)
