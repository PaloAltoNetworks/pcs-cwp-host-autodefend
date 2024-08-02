#!/usr/bin/bash


# Environment variables:
: '
    PCC_URL*: Prisma Cloud Compute Console URL. 
    PCC_SAN: Prisma Cloud Compute Console FQDN or IP. If empty, it will take the FQDN value of PCC_URL
    PCC_USER*: Access Key or Username used to access Prisma Cloud. Must have the Defender Management Read & Write permissions.
    PCC_PASS*: Secret Key or Username used to access Prisma Cloud.
    UPGRADE: If set this will upgrade the existing defender to the latest version.
    AWS_ACCESS_KEY_ID*: Access Key of the User used to Authenticate to AWS.
    AWS_SECRET_ACCESS_KEY*: Secret Key of the User used to Authenticate to AWS.
    AWS_EXTERNAL_ID*: External Id used assume role.
    AWS_ROLE_NAME*: Name of the Role to be assumed by the user.
    AWS_REGION: Region to use at first when Querying the total accounts. Default value: us-east-1
    REGIONS**: Regions where the defender is going to be deployed. If not set, the defender will be deployed in all available regions
    INCLUDED_ACCOUNTS**: accounts to include when script is executed. If empty will scan all the accounts within the tenant.
    EXCLUDED_ACCOUNTS**: accounts to exclude when script is executed.
    INCLUDE_TAG: VM Instances to be included if they have certain tag.
    EXCLUDE_TAG: VM Instances to be excluded if they have certain tag.

    * means required
    ** list of values separated by comma. ex. value1,value2
'
#Extract Console SAN of PCC_URL if not exists
[[ -z "${PCC_SAN}" ]] && PCC_SAN="$(echo $PCC_URL | awk -F[/:] '{print $4}')"

#Turn REGIONS variable into a list
[[ -z "${REGIONS}" ]] && regions=() || IFS=',' read -r -a regions <<< "$REGIONS"

#Initialize AWS_REGION
[[ -z "${AWS_REGION}" ]] && export AWS_REGION="us-east-1" || export AWS_REGION

#Verify if required variables are set
if [ -z $PCC_URL ] || [ -z $PCC_USER ] || [ -z $PCC_PASS ]
then
    echo "Any of the mandatory environment variables PCC_URL, PCC_USER or PCC_PASS are not set"
    exit 1
fi

#Obtaining existing accounts
if [[ -z "${AWS_ACCESS_KEY_ID}" ]] && [[ -z "${AWS_SECRET_ACCESS_KEY}" ]] && [[ -z "${AWS_EXTERNAL_ID}" ]] && [[ -z "${AWS_ROLE_NAME}" ]] 
then
    echo "Any of the mandatory environment variables AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_EXTERNAL_ID or AWS_ROLE_NAME are not set"
    exit 1
else
    echo "Obtaining existing accounts"
    accounts=( $(aws organizations list-accounts | jq -r ".Accounts[].Id" ) )
    main_access_key_id=$AWS_ACCESS_KEY_ID
    main_secret_access_key=$AWS_SECRET_ACCESS_KEY
fi

if [ -n "$INCLUDED_ACCOUNTS" ]
then
    echo "Using only accounts listed in environment variable INCLUDED_ACCOUNTS"
    IFS=',' read -r -a accounts <<< "$INCLUDED_ACCOUNTS"
fi

[[ -z "${EXCLUDED_ACCOUNTS}" ]] && excluded_accounts=() || IFS=',' read -r -a excluded_accounts <<< "$EXCLUDED_ACCOUNTS"

#Obtain Compute Console version
token=$(curl -s -k ${PCC_URL}/api/v1/authenticate -X POST -H "Content-Type: application/json" -d '{
"username":"'"$PCC_USER"'",
"password":"'"$PCC_PASS"'"
}'  | jq -r '.token')
console_version=$(curl -s -k -H "Authorization: Bearer $token" ${PCC_URL}/api/v1/version | tr -d '"')
echo "Prisma Cloud Compute Console version: $console_version"

#Verify if cluster has the defender installed in the accounts
for account in "${accounts[@]}"
do
    #Skipping accounts in the excluded list
    if [[ ${excluded_accounts[@]} =~ $account ]]
    then
        echo "Skipping account ID $account"
        continue
    fi
    
    #Setting Account environment variables
    echo "Accessing Account: $account"
    assume_role_credentials=$(aws sts assume-role --role-arn "arn:aws:iam::$account:role/$AWS_ROLE_NAME" --role-session-name $AWS_ROLE_NAME --external-id $AWS_EXTERNAL_ID)
    export AWS_ACCESS_KEY_ID=$(echo $assume_role_credentials | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo $assume_role_credentials | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo $assume_role_credentials | jq -r '.Credentials.SessionToken')
    
    #Getting existing available credentials
    [[ -z "${REGIONS}" ]] && regions=( $(aws ec2 describe-regions | jq -r '.Regions[].RegionName') )

    #Looping through regions
    for region in "${regions[@]}"
    do
        export AWS_REGION=$region

        echo "Getting instances in region $region"
        aws ec2 describe-instances --query "Reservations[*].Instances[*]" | jq -c '.[][]' | while read -r vm_instance
        do
            #Retrieving Instance values
            instance_id=$(echo $vm_instance | jq -r '.InstanceId')
            instance_name=$(echo $vm_instance | jq -r '.InstanceId')
            resource_group=$(echo $vm_instance | jq -r '.resourceGroup')
            os_type=$(echo $vm_instance | jq -r '.PlatformDetails')
            

            echo "Instance: $instance_name. OS Type: $os_type"
            

            #Excluding instances by tag
            if [ -n "$EXCLUDE_TAG" ]
            then
                exclude_tag_value=$(echo $vm_instance | jq -r --arg skip "$EXCLUDE_TAG" '.Tags[$skip]')
                if [ "$exclude_tag_value" != null ]
                then
                    echo "Excluding instance $instance_name due to it has the tag: $EXCLUDE_TAG. Value: $exclude_tag_value"
                    continue
                fi
            fi

            #EIncluding instances by tag
            if [ -n "$INCLUDE_TAG" ]
            then
                include_tag_value=$(echo $vm_instance | jq -r --arg add "$INCLUDE_TAG" '.Tags[$add]')
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
            }' | jq -r '.token')

            #Check if the defender is installed in the instance or if it requires to be upgraded
            pc_instances_data=$(curl -m 600 -s -k "$PCC_URL/api/v1/defenders?accountIDs=$account&search=$instance_id&offset=0&limit=50" -H "Authorization: Bearer $token")
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
            if [ "$os_type" == "Linux/UNIX" ]
            then
                script_content=$(base64 -w 0 linux.sh)
                aws ssm send-command \
                --instance-ids "$instance_id" \
                --document-name "AWS-RunShellScript" \
                --comment "Installing Prisma Cloud Defender on $os_type instance" \
                --parameters 'commands=["echo \"'$script_content'\" | base64 --decode > /tmp/script.sh && sudo bash /tmp/script.sh \"'$token'\" \"'$PCC_URL'\" \"'$PCC_SAN'\" && rm -rf /tmp/script.sh"]' \
                --output text > /dev/null
            
            elif [ "$os_type" == "Windows" ]
            then
                script_content=$(<windows.ps1)
                script_with_params="\$token='$token'; \$PCC_URL='$PCC_URL'; \$PCC_SAN='$PCC_SAN'; $script_content"
                encoded_script=$(echo -n "$script_with_params" | iconv -f utf8 -t utf16le | base64 -w 0)
                command="powershell -NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded_script"
                aws ssm send-command \
                --instance-ids "$instance_id" \
                --document-name "AWS-RunPowerShellScript" \
                --comment "Installing Prisma Cloud Defender on $os_type instance" \
                --parameters commands=["$command"] \
                --output text > /dev/null
            fi
        done
    done


    #Returning to Main Access Key ID and Secret Key
    export AWS_ACCESS_KEY_ID=$main_access_key_id
    export AWS_SECRET_ACCESS_KEY=$main_secret_access_key
    export AWS_SESSION_TOKEN=""
done
echo "Done"