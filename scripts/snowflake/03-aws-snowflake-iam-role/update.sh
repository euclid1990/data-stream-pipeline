#!/bin/bash

# Get the directory of the currently executing script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Include the configuration file
source "$SCRIPT_DIR/./../../assume.sh"

ROLE_NAME="Snowflake-Role"

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <STORAGE_AWS_IAM_USER_ARN> <STORAGE_AWS_EXTERNAL_ID>"
    exit 1
fi

# Assign input parameters to variables
STORAGE_AWS_IAM_USER_ARN="$1"
STORAGE_AWS_EXTERNAL_ID="$2"

# Update the assume role policy document
aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Effect\": \"Allow\",
      \"Action\": \"sts:AssumeRole\",
      \"Principal\": {
        \"AWS\": \"$STORAGE_AWS_IAM_USER_ARN\"
      },
      \"Condition\": {
        \"StringEquals\": {
          \"sts:ExternalId\": \"$STORAGE_AWS_EXTERNAL_ID\"
        }
      }
    }
  ]
}"

echo "IAM role '$ROLE_NAME' assume-role-policy updated successfully."
