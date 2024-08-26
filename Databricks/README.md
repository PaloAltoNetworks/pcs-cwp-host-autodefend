# Deploy Prisma Cloud Defender in Databricks
This guide shows how to deploy Prisma Cloud Defender in Databricks Cluster

## Step 1: Prisma Cloud Service Account
It's required to create the service account as instructed in the [Pre-requisites](https://github.com/PaloAltoNetworks/pcs-cwp-host-autodefend?tab=readme-ov-file#permissions)

## Step 2: Store the secrets
It's is required to create secrets either through the Databricks default secret storage or through any Secrets service of your choice. In this scenario, it will be used the Databricks default secret storage. To do that do the following:

1. Download [databricks cli](https://docs.databricks.com/en/dev-tools/cli/tutorial.html) if not installed.
2. Create an [Personal Access Token](https://docs.databricks.com/en/dev-tools/auth/pat.html) to authenticate with databricks. The user or Service Account must have access to create secret scopes and create secrets in such scope.
2. Configure databricks with the following command:
    ```bash
    databricks configure
    ```
    Please include the Personal Access Token and the Databricks URL to authenticate
3. Create a secret scope called **prismacloud**
    ```bash
    databricks secrets create-scope prismacloud
    ```
4. Store the [general variables](https://github.com/PaloAltoNetworks/pcs-cwp-host-autodefend?tab=readme-ov-file#general-variables) in the scope.
    ```bash
    databricks secrets put-secret prismacloud PCC_URL
    databricks secrets put-secret prismacloud PCC_USER
    databricks secrets put-secret prismacloud PCC_PASS
    databricks secrets put-secret prismacloud PCC_SAN
    ```
    This values should be saved as text not as json.

> **NOTE**
> This process can change depending on your Secrets Management providers. Please refer to you corresponding provider to verify the integration.

## Step 3: Setup Init Script
To install the defender you can use a [Cluster-scoped init script](https://docs.databricks.com/en/init-scripts/cluster-scoped.html), to install the defender in a single cluster, or a [Global init script](https://docs.databricks.com/en/init-scripts/global.html) to install the defender across all the clusters in your environment. The contents of the script should be the one in the *databricks.sh* file.

## Step 4: Load Secrets as Environment variables
When creating or updating a cluster, it's required to retrieve the secrets stored. To do that please include the following environment variables in the Advanced Settings of the Cluster configuration:
```bash
PCC_SAN={{secrets/prismacloud/PCC_SAN}}
PCC_URL={{secrets/prismacloud/PCC_URL}}
PCC_PASS={{secrets/prismacloud/PCC_PASS}}
PCC_USER={{secrets/prismacloud/PCC_USER}}
```
For already existing Clusters, it is required to restart the cluster so the defender gets installed.