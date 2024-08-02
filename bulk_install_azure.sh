#!/usr/bin/bash


# Environment variables:
: '
    PCC_URL*: Prisma Cloud Compute Console URL. 
    PCC_SAN: Prisma Cloud Compute Console FQDN or IP. If empty, it will take the FQDN value of PCC_URL
    PCC_USER*: Access Key or Username used to access Prisma Cloud. Must have the Defender Management Read & Write permissions.
    PCC_PASS*: Secret Key or Username used to access Prisma Cloud.
    UPGRADE: If set this will upgrade the existing defender to the latest version.
    AZURE_TENANT_ID: Tenant ID to be used. Required only if the script is used using a Service Principal.
    AZURE_APP_ID: Client ID or Application ID of the Service Principal.
    AZURE_APP_KEY: Client Secret of the Service Principal.
    REGIONS**: Regions where the defender is going to be deployed.
    INCLUDED_SUBSCRIPTIONS**: Subscriptions to include when script is executed. If empty will scan all the Subscriptions within the tenant.
    EXCLUDED_SUBSCRIPTIONS**: Subscriptions to exclude when script is executed.
    INCLUDE_TAG: VM Instances to be included if they have certain tag.
    EXCLUDE_TAG: VM Instances to be excluded if they have certain tag.

    * means required
    ** list of values separated by comma. ex. value1,value2
'
#Extract Console SAN of PCC_URL if not exists
[[ -z "${PCC_SAN}" ]] && PCC_SAN="$(echo $PCC_URL | awk -F[/:] '{print $4}')"

#Turn REGIONS variable into a list
[[ -z "${REGIONS}" ]] && regions=() || IFS=',' read -r -a regions <<< "$REGIONS"

#Verify if required variables are set
if [ -z $PCC_URL ] || [ -z $PCC_USER ] || [ -z $PCC_PASS ]
then
    echo "Any of the mandatory environment variables PCC_URL, PCC_USER or PCC_PASS are not set"
    exit 1
fi

#Obtaining existing subscriptions
if [ -z $AZURE_APP_ID ] && [ -z $AZURE_APP_KEY ] && [ -z $AZURE_TENANT_ID ]
then
    echo "Obtaining existing subscriptions"
    subscriptions=( $(az account subscription list | jq -r ".[] | .subscriptionId") )
else
    echo "Logging in into Azure using Service Principal"
    subscriptions=( $(az login --service-principal -u ${AZURE_APP_ID} -p ${AZURE_APP_KEY} --tenant ${AZURE_TENANT_ID} | jq -r ".[] | .id") )
fi

if [ -n "$INCLUDED_SUBSCRIPTIONS" ]
then
    echo "Using only subscriptions listed in environment variable INCLUDED_SUBSCRIPTIONS"
    IFS=',' read -r -a subscriptions <<< "$INCLUDED_SUBSCRIPTIONS"
fi

[[ -z "${EXCLUDED_SUBSCRIPTIONS}" ]] && excluded_subscriptions=() || IFS=',' read -r -a excluded_subscriptions <<< "$EXCLUDED_SUBSCRIPTIONS"

#Obtain Compute Console version
token=$(curl -s -k ${PCC_URL}/api/v1/authenticate -X POST -H "Content-Type: application/json" -d '{
"username":"'"$PCC_USER"'",
"password":"'"$PCC_PASS"'"
}'  | jq -r '.token')
console_version=$(curl -s -k -H "Authorization: Bearer $token" ${PCC_URL}/api/v1/version | tr -d '"')
echo "Prisma Cloud Compute Console version: $console_version"

#Verify if cluster has the defender installed in the subscriptions
for subscription in "${subscriptions[@]}"
do

    #Skipping subscriptions in the excluded list
    if [[ ${excluded_subscriptions[@]} =~ $subscription ]]
    then
        echo "Skipping Subscription ID $subscription"
        continue
    fi
    
    #Setting subscription
    echo "Accessing Subscription: $subscription"
    az account set --subscription $subscription

    #Looping through VM Instances
    az vm list --only-show-errors | jq -c '.[]' | while read -r vm_instance
    do
        #Retrieving Instance values
        instance_name=$(echo $vm_instance | jq -r '.name')
        resource_group=$(echo $vm_instance | jq -r '.resourceGroup')
        os_type=$(echo $vm_instance | jq -r '.storageProfile.osDisk.osType')
        region=$(echo $vm_instance | jq -r '.location')
        
        if [[ ! ${regions[@]} =~ $region ]] && [ -n "$regions" ]
        then
            echo "Skipping Instance $instance_name for not being in the following regions: $regions. Current region: $region"
            continue
        fi

        echo "Instance: $instance_name. OS Type: $os_type. Resource Group: $resource_group. Region: $region"
        

        #Excluding instances by tag
        if [ -n "$EXCLUDE_TAG" ]
        then
            exclude_tag_value=$(echo $vm_instance | jq -r --arg skip "$EXCLUDE_TAG" '.tags[$skip]')
            if [ "$exclude_tag_value" != null ]
            then
                echo "Excluding instance $instance_name due to it has the tag: $EXCLUDE_TAG. Value: $exclude_tag_value"
                continue
            fi
        fi

        #EIncluding instances by tag
        if [ -n "$INCLUDE_TAG" ]
        then
            include_tag_value=$(echo $vm_instance | jq -r --arg add "$INCLUDE_TAG" '.tags[$add]')
            if [ "$include_tag_value" != null ]
            then
                echo "Including instance $instance_name due to it has the tag: $INCLUDE_TAG. Value: $include_tag_value"
            else
                echo "Excluding instance $instance_name due to it does not have the tag: $INCLUDE_TAG"
                continue
            fi
        fi

        #Generate Console TOKEN
        token=$(curl -s -k ${PCC_URL}/api/v1/authenticate -X POST -H "Content-Type: application/json" -d '{
        "username":"'"$PCC_USER"'",
        "password":"'"$PCC_PASS"'"
        }'  | jq -r '.token')

        #Since Windows only supports 15 characters in it's hostname, then the instance name to search in prisma must contain less than 15 characters
        search_string=$instance_name
        if [ "$os_type" == "Windows" ]
        then
            if [[ ${#instance_name} -gt 15 ]]
            then
                search_string="${instance_name:0:15}"
            fi
        fi

        #Check if the defender is installed in the instance or if it requires to be upgraded
        pc_instances_data=$(curl -m 600 -s -k "$PCC_URL/api/v1/defenders?accountIDs=$subscription&search=$search_string&offset=0&limit=50" -H "Authorization: Bearer $token")
        if [ "$pc_instances_data" != null ]
        then
            connected="false"
            while read -r pc_instance
            do
                connected=$(echo $pc_instance | jq -r '.connected')
                if [ "$connected" == "true" ]
                then
                    defender_version=$(echo $pc_instance | jq -r '.version')
                    defender_type=$(echo $pc_instance | jq -r '.type')
                    defender_cluster=$(echo $pc_instance | jq -r '.cluster')
                    defender_hostname=$(echo $pc_instance | jq -r '.hostname')
                    break
                fi
            done <<< "$(echo $pc_instances_data | jq -c '.[]')"

            if [ "$connected" == "true" ]
            then
                echo "Instance $instance_name has the defender installed. Defender version: $defender_version. Defender type: $defender_type"
                if [ "$UPGRADE" == "yes" ] && [ "$defender_version" != "$console_version" ] && [ "$defender_cluster" == null ]
                then
                    echo "Upgrading defender to new version $console_version"
                    curl -s -k "$PCC_URL/api/v1/defenders/$defender_hostname/upgrade" -X POST -H "Authorization: Bearer $token"
                    echo "Defender upgraded successfully"
                fi
                continue
            else
                echo "Defender disconnected on instance $instance_name. Installing defender version $console_version"
            fi
        else
            echo "Defender not installed on instance $instance_name. Installing defender version $console_version"
        fi

        #Execute Run command based on the instance type
        if [ "$os_type" == "Linux" ]
        then
            script_content=$(cat linux.sh)
            az vm run-command invoke \
            -g $resource_group \
            -n $instance_name \
            --command-id RunShellScript \
            --scripts "$script_content" \
            --parameters param1="$token" param2="$PCC_URL" param3="$PCC_SAN"
        
        elif [ "$os_type" == "Windows" ]
        then
            script_content=$(cat windows.ps1)
            az vm run-command invoke \
            -g $resource_group \
            -n $instance_name \
            --command-id RunPowerShellScript \
            --scripts "$script_content"\
            --parameters token="$token" PCC_URL="$PCC_URL" PCC_SAN="$PCC_SAN"
        fi
    done
done
echo "Done"