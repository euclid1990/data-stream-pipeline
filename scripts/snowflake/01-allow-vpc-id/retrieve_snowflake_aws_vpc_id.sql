-- Active admin role for the user session
USE ROLE ACCOUNTADMIN;

-- Retrieve the IDs of the AWS Virtual Network in which Snowflake account is located
SELECT SYSTEM$GET_SNOWFLAKE_PLATFORM_INFO();
