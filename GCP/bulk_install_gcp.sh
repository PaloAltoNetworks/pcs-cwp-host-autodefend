#!/usr/bin/bash


# Environment variables:
: '
    PCC_URL*: Prisma Cloud Compute Console URL. 
    PCC_SAN: Prisma Cloud Compute Console FQDN or IP. If empty, it will take the FQDN value of PCC_URL
    PCC_USER*: Access Key or Username used to access Prisma Cloud. Must have the Defender Management Read & Write permissions.
    PCC_PASS*: Secret Key or Username used to access Prisma Cloud.
    UPGRADE: If set this will upgrade the existing defender to the latest version.
    SERVICE_ACCOUNT: Email associated with the Service Account.
    KEY_FILE: Path to the Service Account Key File.
    REGIONS**: Regions where the defender is going to be deployed.
    INCLUDED_PROJECTS**: projects to include when script is executed. If empty will scan all the projects within the tenant.
    EXCLUDED_PROJECTS**: projects to exclude when script is executed.
    INCLUDED_LABELS**: VM Instances to be included if they have certain tag.
    EXCLUDED_LABELS**: VM Instances to be excluded if they have certain tag.

    * means required
    ** list of values separated by space. ex. value1 value2
'
#List of supported OS
SUPPORTED_OS="ubuntu debian centos rhel suse rocky cos"

#Extract Console SAN of PCC_URL if not exists
[[ -z "${PCC_SAN}" ]] && PCC_SAN="$(echo $PCC_URL | awk -F[/:] '{print $4}')"

#Obtain zones from particular regions
if [ -n "${REGIONS}" ]
then
    zones=$(gcloud compute zones list --filter="region:(regions/$REGIONS)" --format="value(name)")
fi

#Verify if required variables are set
if [ -z $PCC_URL ] || [ -z $PCC_USER ] || [ -z $PCC_PASS ]
then
    echo "Any of the mandatory environment variables PCC_URL, PCC_USER or PCC_PASS are not set"
    exit 1
fi

#Login to gcloud using Service Account
if [ -n "$SERVICE_ACCOUNT" ] && [ -n "$KEY_FILE" ]
then
    echo "Authenticating with Service Account: $SERVICE_ACCOUNT"
    gcloud auth activate-service-account $SERVICE_ACCOUNT --key-file $KEY_FILE
fi

if [ -n "$INCLUDED_PROJECTS" ]
then
    echo "Using only projects: $INCLUDED_PROJECTS"
    IFS=' ' read -r -a projects <<< "$INCLUDED_PROJECTS"
else
    projects=( $(gcloud projects list --format="value(projectId)") )
fi

#Set which projects to exclude
[[ -n "${EXCLUDED_PROJECTS}" ]] && IFS=' ' read -r -a excluded_projects <<< "$EXCLUDED_PROJECTS" && echo "Excluding projects: $EXCLUDED_PROJECTS" || excluded_projects=()

#Generating command line to retrieve the VM Instances
command='gcloud compute instances list --format "json(name, zone)" --filter "status:(RUNNING)" --filter "disks[].licenses:('$SUPPORTED_OS')"'

[[ -n "$zones" ]] && command=''$command' --filter "zone:('$zones')"' && echo "Including instances that are in the following regions: $REGIONS"
[[ -n "$EXCLUDED_LABELS" ]] && command=''$command' --filter "NOT labels[]:('$EXCLUDED_LABELS')"' && echo "Excluding instances that do not have the following labels: $EXCLUDED_LABELS"
[[ -n "$INCLUDED_LABELS" ]] && command=''$command' --filter "labels[]:('$INCLUDED_LABELS')"' && echo "Include instances that have the following labels: $INCLUDED_LABELS"


#Obtain Compute Console version
token=$(curl -s -k ${PCC_URL}/api/v1/authenticate -X POST -H "Content-Type: application/json" -d '{
"username":"'"$PCC_USER"'",
"password":"'"$PCC_PASS"'"
}'  | jq -r '.token')
console_version=$(curl -s -k -H "Authorization: Bearer $token" ${PCC_URL}/api/v1/version | tr -d '"')
echo "Prisma Cloud Compute Console version: $console_version"

#Verify if cluster has the defender installed in the projects
for project in "${projects[@]}"
do

    #Skipping projects in the excluded list
    if [[ ${excluded_projects[@]} =~ $project ]]
    then
        echo "Skipping project ID $project"
        continue
    fi
    
    #Setting project
    echo "Accessing project: $project"
    gcloud config set project $project &> /dev/null 

    #Looping through VM Instances
    eval $command | jq -c '.[]' | while read -r vm_instance
    do
        #Retrieving Instance values
        instance_name=$(echo $vm_instance | jq -r '.name')
        zone=$(echo $vm_instance | jq -r '.zone')

        #Generate Console TOKEN
        token=$(curl -s -k ${PCC_URL}/api/v1/authenticate -X POST -H "Content-Type: application/json" -d '{
        "username":"'"$PCC_USER"'",
        "password":"'"$PCC_PASS"'"
        }'  | jq -r '.token')

        #Check if the defender is installed in the instance or if it requires to be upgraded
        pc_instances_data=$(curl -m 600 -s -k "$PCC_URL/api/v1/defenders?accountIDs=$project&search=$instance_name&offset=0&limit=50" -H "Authorization: Bearer $token")
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

        #Install Prisma Cloud Defender on Linux instances
        script=$(cat linux.sh | base64 -w 0)
        gcloud compute ssh "$instance_name" --zone "$zone" --tunnel-through-iap --command "echo \"$script\" | base64 -d > /tmp/install_defender.sh && bash /tmp/install_defender.sh $token $PCC_URL $PCC_SAN && rm /tmp/install_defender.sh"
    done
done
echo "Done"