#!/bin/bash

# Get the directory of the currently executing script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Include the configuration file
source "$SCRIPT_DIR/config.sh"

# Read variables from the .env file
source "$SCRIPT_DIR/.env"

##############################################################
# Create IAM role and grant required policies
##############################################################

# Check if IAM user exists
if aws iam get-user --user-name "$USER_NAME" &> /dev/null; then
    echo "IAM user '$USER_NAME' exists. Nothing to do"
    # exit 0
else
    echo "IAM user '$USER_NAME' does not exist."
fi

echo "Create IAM user '$USER_NAME'"

# AWS user creation
aws iam create-user --user-name $USER_NAME

# Attach inline policy to the user from a local JSON file
aws iam put-user-policy --user-name $USER_NAME --policy-name $USER_POLICY_NAME --policy-document file://assets/assume-role-policy.json

# Get your AWS account ID and store it in a variable
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

echo "Create IAM role '$ROLE_NAME'"

# AWS role creation with dynamic account ID
aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "'"${ACCOUNT_ID}"'"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

echo "Attach policies to role '$ROLE_NAME'"

# Attach policies to the role
## CDK required policies
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AWSCloudFormationFullAccess
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonSSMFullAccess
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
## Lab required policies
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonKinesisFullAccess
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonKinesisFirehoseFullAccess
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess

##############################################################
# Create access key for the IAM user and
# configure AWS CLI profile with the obtained credentials
##############################################################

# Check if access keys exist for the IAM user
ACCESS_KEYS=$(aws iam list-access-keys --user-name "$USER_NAME" --query 'AccessKeyMetadata')

if [ "$(echo "$ACCESS_KEYS" | grep -c 'AccessKeyId')" -eq 0 ]; then
  echo "Create access key for IAM user '$USER_NAME'"

  # Create access key for the IAM user and store the output in a variable
  CREATED_ACCESS_KEY=$(aws iam create-access-key --user-name $USER_NAME)

  # Extract access key ID and secret access key using Bash string manipulation
  ACCESS_KEY_ID=$(echo $CREATED_ACCESS_KEY | grep -o '"AccessKeyId": "[^"]*' | cut -d'"' -f4)
  SECRET_ACCESS_KEY=$(echo $CREATED_ACCESS_KEY | grep -o '"SecretAccessKey": "[^"]*' | cut -d'"' -f4)

  # Configure AWS CLI profile with the obtained credentials
  aws configure set aws_access_key_id "$ACCESS_KEY_ID" --profile $USER_NAME
  aws configure set aws_secret_access_key "$SECRET_ACCESS_KEY" --profile $USER_NAME

  # Configure AWS CLI profile with default region
  aws configure set region $CDK_REGION --profile $USER_NAME

  # Configure AWS CLI profile to output JSON
  aws configure set output json --profile $USER_NAME

  # Disable the pager for AWS CLI profile
  aws configure set cli_pager "" --profile $USER_NAME
else
    echo "Access keys exist for IAM user '$USER_NAME'"
    echo "Access Key ID(s):"

    # Extract Access Key IDs without using jq
    for KEY in $(echo "$ACCESS_KEYS" | awk -F'"' '/AccessKeyId/ {print $4}'); do
      echo "$KEY"
    done
fi

