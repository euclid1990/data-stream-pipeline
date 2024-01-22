#!/bin/bash

# Get the directory of the currently executing script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Include the configuration file
source "$SCRIPT_DIR/./../../assume.sh"

# Read variables from the .env file
source "$SCRIPT_DIR/./../../../.env"

# Set the path to your outputs.json file
OUTPUTS_FILE="$SCRIPT_DIR/./../../../outputs.json"

# Read the s3BucketName from the file
S3_BUCKET_NAME=$(jq -r ".$CDK_STACK.s3BucketName" "$OUTPUTS_FILE")

ROLE_NAME="Snowflake-Role"

POLICY_NAME="SnowflakeS3AccessPolicy"

# Temporary AWS account ID of the 3rd party
ALLOWED_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

# Check if the role already exists
if aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
    # Role already exists
    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
    echo "IAM role '$ROLE_NAME' already exists with ARN: $ROLE_ARN."
else
    # Role does not exist, create it
    ROLE_ARN=$(aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document "{
      \"Version\": \"2012-10-17\",
      \"Statement\": [
        {
          \"Effect\": \"Allow\",
          \"Principal\": {
            \"AWS\": \"arn:aws:iam::$ALLOWED_ACCOUNT_ID:root\"
          },
          \"Action\": \"sts:AssumeRole\"
        }
      ]
    }" --query 'Role.Arn' --output text)

    # Attach the s3 access policy to the IAM role
    aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/$POLICY_NAME"

    echo "IAM assume role '$ROLE_NAME' created and policy '$POLICY_NAME' attached successfully."

    echo "IAM role '$ROLE_NAME' created with ARN: $ROLE_ARN."
fi

SQL_COMMANDS=$(cat <<EOL
-- Specify the role
USE ROLE ACCOUNTADMIN;

-- Drop database
DROP DATABASE IF EXISTS s3_to_snowflake;

-- Create database
CREATE DATABASE IF NOT EXISTS s3_to_snowflake;

-- Specify the active database for the session.
USE s3_to_snowflake;

-- Create S3 Storage Integration in Snowflake
CREATE STORAGE INTEGRATION s3_int
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = '${ROLE_ARN}'
  STORAGE_ALLOWED_LOCATIONS = ('s3://${S3_BUCKET_NAME}/')
  COMMENT = 'Testing Snowflake getting refresh or not';

-- Retrieve the AWS IAM User for your Snowflake Account
DESC INTEGRATION s3_int;

-- File Format Creation
CREATE OR REPLACE FILE FORMAT my_csv_format
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY='"';

-- Delete existing stage / Just drop database

-- For delete existing stage / Just drop database

-- External Stage Creation
CREATE STAGE my_s3_stage
  STORAGE_INTEGRATION = s3_int
  URL = 's3://${S3_BUCKET_NAME}'
  FILE_FORMAT = my_csv_format;

-- List the stages in Snowflake / Show all S3 buckets related stage
LIST @my_s3_stage;

-- Table Creation without structure
CREATE OR REPLACE EXTERNAL TABLE s3_to_snowflake.PUBLIC.Orders WITH LOCATION = @my_s3_stage FILE_FORMAT ='my_csv_format';

-- Table Creation with structure
CREATE OR REPLACE EXTERNAL TABLE s3_to_snowflake.PUBLIC.Orders (
  id INTEGER AS (value:c1::INTEGER),
  order_id STRING AS (value:c2::STRING),
  customer_id INTEGER AS (value:c3::INTEGER),
  product_name STRING AS (value:c4::STRING),
  product_quantity INTEGER AS (value:c5::INTEGER),
  product_price INTEGER AS (value:c6::INTEGER),
  phone_number STRING AS (value:c7::STRING),
  address STRING AS (value:c8::STRING),
  city STRING AS (value:c9::STRING),
  country STRING AS (value:c10::STRING),
  order_cost INTEGER AS (value:c11::INTEGER),
  order_date DATETIME AS (value:c12::DATETIME),
  generate_date DATETIME AS (value:c13::DATETIME)
)
WITH LOCATION = @my_s3_stage FILE_FORMAT ='my_csv_format'
AUTO_REFRESH = TRUE;

-- Describes either the columns in a table or the current values
DESCRIBE TABLE s3_to_snowflake.PUBLIC.Orders;

-- Get notification_channel ARN
SHOW EXTERNAL TABLES;

-- Retrieve the history of data loaded
SELECT table_name, last_load_time
FROM information_schema.load_history
WHERE table_name='Orders'
ORDER BY last_load_time DESC
LIMIT 10;

-- Create new warehouse
CREATE WAREHOUSE IF NOT EXISTS my_s3_warehouse
  WAREHOUSE_SIZE = 'XSMALL'
  WAREHOUSE_TYPE = 'STANDARD'
  AUTO_SUSPEND = 600
  AUTO_RESUME = TRUE;

-- Show all wearhouse
SHOW WAREHOUSES;

-- Use the warehouse
USE WAREHOUSE my_s3_warehouse;

-- Query the stage
SELECT
    t.\$1 as id,
    t.\$2 as order_id,
    t.\$3 as customer_id,
    t.\$4 as product_name,
    t.\$12 as order_date,
    t.\$13 as generate_date
FROM @my_s3_stage t;

-- Query the table with column name / If define table structure
SELECT
    id,
    order_id,
    customer_id,
    product_name,
    order_date,
    generate_date
FROM s3_to_snowflake.PUBLIC.Orders
ORDER BY id DESC
LIMIT 100;

-- Query the table with parse JSON / If NOT define table structure
SELECT
    parse_json(\$1):c1 as id,
    parse_json(\$1):c2 as order_id,
    parse_json(\$1):c3 as customer_id,
    parse_json(\$1):c4 as product_name,
    parse_json(\$1):c12 as order_date,
    parse_json(\$1):c13 as generate_date
FROM s3_to_snowflake.PUBLIC.Orders;

-- Retrieve the billing history for an external table in last 12 hours, by 1 hour periods
SELECT *
  FROM TABLE(information_schema.auto_refresh_registration_history(
    date_range_start=>dateadd('hour',-12,current_timestamp()),
    object_type=>'external_table',
    object_name=>'s3_to_snowflake.PUBLIC.Orders'));
EOL
)

echo "$SQL_COMMANDS" > "$SCRIPT_DIR/integration.sql"

echo "****************************************"
echo "[1] Output SQL commands to run on Snowflake Worksheet at./scripts/snowflake/03-aws-snowflake-iam-role/integration.sql"
echo "[2] Please run SQL \"DESC INTEGRATION s3_int;\" to get STORAGE_AWS_IAM_USER_ARN / STORAGE_AWS_EXTERNAL_ID"
echo "[3] Execute command -- $ ./scripts/snowflake/03-aws-snowflake-iam-role/update.sh <STORAGE_AWS_IAM_USER_ARN> <STORAGE_AWS_EXTERNAL_ID>"
echo "[4] Please run SQL \"SHOW EXTERNAL TABLES;\" to get notification_channel SQL arn"
echo "[5] Execute command -- $ ./scripts/snowflake/04-aws-s3-event-notification/create.sh <notification_channel_arn>"
echo "****************************************"
