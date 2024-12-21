#!/bin/bash
# Variables
SECRET_PROJECT_ID="$1"
SECRET_NAME="$2"
[[ -z "$3" ]] && LOG_FILE="/tmp/install_defender.log" || LOG_FILE="$3"

# Installing jq and curl (if not installed)
not_installed_packages=""
if ! command -v curl &> $LOG_FILE; then not_installed_packages+="curl"; fi
if ! command -v jq &> $LOG_FILE; then not_installed_packages+=" jq"; fi

if [[ -n "$not_installed_packages" ]]
then
    echo "Packages $not_installed_packages not installed. Installing pending packages..."
    if command -v yum > $LOG_FILE 
    then
        eval "sudo yum install -y $not_installed_packages" > $LOG_FILE
    else
        eval "sudo apt update &> $LOG_FILE && sudo apt install -y $not_installed_packages &> $LOG_FILE"
    fi
fi

# Obtain access token
ACCESS_TOKEN=$(curl -s -H "Metadata-Flavor: Google" "http://metadata/computeMetadata/v1/instance/service-accounts/default/token" | jq -r '.access_token')

# Retrieve the secret
SECRET_JSON=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" "https://secretmanager.googleapis.com/v1/projects/$SECRET_PROJECT_ID/secrets/$SECRET_NAME/versions/latest:access" | jq -r '.payload.data' | base64 -d)

# Export the secret variables
PCC_URL=$(echo "$SECRET_JSON" | jq -r '.PCC_URL')
PCC_USER=$(echo "$SECRET_JSON" | jq -r '.PCC_USER')
PCC_PASS=$(echo "$SECRET_JSON" | jq -r '.PCC_PASS')
PCC_SAN=$(echo "$SECRET_JSON" | jq -r '.PCC_SAN')

[[ -z "$PCC_URL" ]] && echo "Please verify that the Service Account used for this VM has access to the Secret, the secret $SECRET_NAME in the project $SECRET_PROJECT_ID exists and that the access to the GCP APIs is global" > $LOG_FILE && exit 1

# Retrieving Prisma Cloud Console Token
token=$(curl -s -k "$PCC_URL/api/v1/authenticate" -X POST -H "Content-Type: application/json" -d '{"username":"'"$PCC_USER"'", "password":"'"$PCC_PASS"'"}' | jq -r '.token')

[[ -z "$token" ]] && echo "Invalid credentials. Please verify if the credentials exists and are not expired" > $LOG_FILE && exit 1

# Installing defender
if sudo docker ps &> $LOG_FILE; then args=""; else args="--install-host"; fi
curl -sSL -k --header "authorization: Bearer $token" -X POST "$PCC_URL/api/v1/scripts/defender.sh" | sudo bash -s -- -c "$PCC_SAN" -m -u $args > $LOG_FILE

# Removing Installed packages
if [[ -n "$not_installed_packages" ]]
then
    echo "Removing the packages $not_installed_packages since were not installed..."
    if command -v yum > $LOG_FILE
    then
        sudo yum remove -y $not_installed_packages &> $LOG_FILE
    else
        sudo apt remove -y $not_installed_packages &> $LOG_FILE
    fi
fi