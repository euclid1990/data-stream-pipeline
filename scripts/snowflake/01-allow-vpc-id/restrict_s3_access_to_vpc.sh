#!/bin/bash

# Get the directory of the currently executing script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Include the configuration file
source "$SCRIPT_DIR/./../../assume.sh"

# Check if vpcId is provided as a parameter
if [ $# -ne 1 ]; then
    echo "Usage: $0 <vpcId>"
    exit 1
fi

# Read variables from the .env file
source "$SCRIPT_DIR/./../../../.env"

# Set the path to your outputs.json file
OUTPUTS_FILE="$SCRIPT_DIR/./../../../outputs.json"

# Read the s3BucketName from the file
S3_BUCKET_NAME=$(jq -r ".$CDK_STACK.s3BucketName" "$OUTPUTS_FILE")

# Get VPC Id for your Snowflake account from command line argument
VPC_ID="$1"

# Get your AWS account ID and store it in a variable
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

# Set the policy JSON with the correct s3BucketName and vpcId
POLICY_JSON=$(cat <<EOL
{
  "Version": "2012-10-17",
  "Id": "Policy1706086485617",
  "Statement": [
    {
      "Sid": "Access-to-specific-VPC-only",
      "Principal": { "AWS": "*" },
      "Action": "s3:*",
      "Effect": "Deny",
      "Resource": [
        "arn:aws:s3:::${S3_BUCKET_NAME}",
        "arn:aws:s3:::${S3_BUCKET_NAME}/*"
      ],
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalAccount": "${ACCOUNT_ID}",
          "aws:SourceVpc": "${VPC_ID}"
        }
      }
    }
   ]
}
EOL
)

# Update the bucket policy using the AWS CLI
aws s3api put-bucket-policy --bucket "$S3_BUCKET_NAME" --policy "$POLICY_JSON"

echo "Bucket policy updated for $S3_BUCKET_NAME with vpcId: $VPC_ID"
