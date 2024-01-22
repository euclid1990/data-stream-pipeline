#!/bin/bash

# Get the directory of the currently executing script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Include the configuration file
source "$SCRIPT_DIR/./../../assume.sh"

# Check if notification_channel_arn is provided as a parameter
if [ $# -ne 1 ]; then
    echo "Usage: $0 <notification_channel_arn>"
    exit 1
fi

# Read variables from the .env file
source "$SCRIPT_DIR/./../../../.env"

# Set the path to your outputs.json file
OUTPUTS_FILE="$SCRIPT_DIR/./../../../outputs.json"

# Read the s3BucketName from the file
S3_BUCKET_NAME=$(jq -r ".$CDK_STACK.s3BucketName" "$OUTPUTS_FILE")

# Get VPC Id for your Snowflake account from command line argument
NOTIFICATION_CHANNEL_ARN="$1"

EVENT_NOTIFICATION_NAME="Auto-ingest Snowflake"

# Configure S3 bucket event notification
aws s3api put-bucket-notification-configuration --bucket $S3_BUCKET_NAME --notification-configuration '{
  "QueueConfigurations": [
    {
      "Id": "'"$EVENT_NOTIFICATION_NAME"'",
      "QueueArn": "'"$NOTIFICATION_CHANNEL_ARN"'",
      "Events": ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    }
  ]
}'

echo "S3 bucket [$S3_BUCKET_NAME] event notification configured successfully to [$NOTIFICATION_CHANNEL_ARN]."
