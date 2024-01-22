#!/bin/bash

# Get the directory of the currently executing script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Include the configuration file
source "$SCRIPT_DIR/./../../assume.sh"

# Read variables from the .env file
source "$SCRIPT_DIR/./../../../.env"

# Set the path to your outputs.json file
OUTPUTS_FILE="$SCRIPT_DIR/./../../../outputs.json"

# Change it if you want rename policy
POLICY_NAME="SnowflakeS3AccessPolicy"

# Read the s3BucketName from the file
S3_BUCKET_NAME=$(jq -r ".$CDK_STACK.s3BucketName" "$OUTPUTS_FILE")

# Create the IAM policy JSON
IAM_POLICY=$(cat <<EOL
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:DeleteObject",
                "s3:DeleteObjectVersion"
            ],
            "Resource": "arn:aws:s3:::${S3_BUCKET_NAME}/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws:s3:::${S3_BUCKET_NAME}"
        }
    ]
}
EOL
)

# Delete the IAM policy
aws iam delete-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/$POLICY_NAME"

# Create the IAM policy
aws iam create-policy --policy-name "$POLICY_NAME" --policy-document "$IAM_POLICY"

echo "IAM policy '$POLICY_NAME' created successfully."
