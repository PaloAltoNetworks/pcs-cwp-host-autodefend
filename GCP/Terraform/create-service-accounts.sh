#!/bin/bash

# Set variables
SERVICE_ACCOUNT_NAME="pcc-secret-access"
SECRET="SECRET_COMPLETE_NAME"
SERVICE_ACCOUNT_DESCRIPTION="Service account for accessing a Prisma Cloud Compute Secrets"

# List all projects in the organization
PROJECTS=( $(gcloud projects list --format="value(projectId)") )

# Loop through each project and create the service account
for PROJECT_ID in "${PROJECTS[@]}"; do
    echo "Accessing to Project: $PROJECT_ID"
    gcloud config set project $PROJECT_ID &> /dev/null 

    # Create Service Account
    echo "Creating Service Account: $SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME --description "$SERVICE_ACCOUNT_DESCRIPTION" --display-name "VM PCC Secret Access" &> /dev/null

    # Grant access to the secret
    echo "Creating Granting Access to Secret"
    gcloud secrets add-iam-policy-binding $SECRET --member "serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" --role "roles/secretmanager.secretAccessor" &> /dev/null

    # Grant access on project level to the role Service Account User
    echo "Granting access to Service Account User"
    gcloud projects add-iam-policy-binding $PROJECT_ID --member "serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" --role roles/iam.serviceAccountUser &> /dev/null
done