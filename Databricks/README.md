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
4. Put the secrets of the () 