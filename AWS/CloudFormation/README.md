# Deploy Prisma Cloud Defenders using CloudFormation
This is a way to deploy Prisma Cloud Defenders on Windows and Linux EC2 Instances using CloudFormation and AWS Secrets Manager at Organization Level.

## Step 1: Create a Service Account in Prisma Cloud
Login to Prisma Cloud go to Settings > Access Control and Create the following Resources:
- **Permissions Group**: This Permissions Group should have only access to the View and Update Defender Deployment permissions.
- **Role**: Must create a Role with only the Check Box that says "On-prem/Other Cloud Providers" and assined the Permissions Group created before.
- **Service Account**: This is going to be the credentials used for deploying defenders.

## Step 2: Create AWS Secret
Login to AWS and go to AWS Secrets Manager service. Then create a Secret as follwing:
1. Type: Other type of secret
2. Key/Value Pairs: Create the following Keys:
    - **PCC_URL**: Prisma Cloud Compute URL. Can be found in Prisma Cloud under Runtime Security > Manage > System > Utilities > Path to the Console
    - **PCC_SAN**: Prisma Cloud Domain Name. Can be extracted from the PCC_URL
    - **PCC_USER**: Access Key of the Service Account Created in Prisma Cloud
    - **PCC_PASS**: Secret Key of the Service Account Created in Prisma Cloud
3. Secret name: Any name of your choice.

Leave all the next to blank or add any additional setting as needed

## Step 3: Create the Roles at Org Level
Go to CloudFormation service and create an the stack of the file **PCSecretsRole.yaml**. This Stack has the following parameters:
- **MasterRoleName**: Name of the Master Role to be assumed to obtain the Secrets to access Prisma Cloud.
- **RoleName**: Name of the Role to be Assigned to the EC2 Instances.
- **SecretArn**: ARN of the Secret created in Step 2.
- **SessionName**: Name of the session to be used while assuming the Master Role. This value can be updated as needed to have control over the access of the Secret.
- **OrganizationId**: Id of the organization. Can be Obtained from AWS Organizations and should start with o-
- **OrganizationalUnitIds**: The Organizational Units where the Role for the EC2 Instance will be created. must start with r- for Root OU, or ou-.

Once created, it should create all the appropriate roles in each Account under the Organization and also a EC2 Instance profile.

## Step 4: Create the EC2 Instance
Now you can create the EC2 Instance using either the templates from the LinuxEC2Instance.yaml or WindowsEC2Instance.yaml. Any of these have the following parameters:
- **InstanceType**: The type of the Instance to be deployed
- **KeyName**: Name of the key to be used for accesing the instance
- **EC2InstanceProfile**: Name of the Instance Profile to be used. The previous template created already the EC2 Instance profile and should be named as the parameter RoleName of the PCSecretsRole CloudFormation Template.
- **SecretArn**: ARN of the Secret created in Step 2.
- **SecretRegion**: Region where the Secret is located.
- **RoleArn**: ARN of the Master Role created in Step 3.
- **SessionName**: Name of the session to be used while assuming the Master Role.
- **AMIId**: Id of the AMI to be launched.

Note: This templates can be  modified to suit your needs. Te Security group can be added, but this as for the moment will use the default security group.

