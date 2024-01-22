unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN

echo "IAM user/role used to call the operation."
aws sts get-caller-identity

# Get the directory of the currently executing script
COMMON_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Include the configuration file
source "$COMMON_SCRIPT_DIR/config.sh"

# Get the ARN of the IAM role
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)

AWS_CREDENTIAL=($(aws sts assume-role --profile $USER_NAME --role-arn $ROLE_ARN --role-session-name AWSCLI-Session --duration-seconds 3600 --query '[Credentials.AccessKeyId,Credentials.SecretAccessKey,Credentials.SessionToken]' --output text))

export AWS_ACCESS_KEY_ID=${AWS_CREDENTIAL[0]}
export AWS_SECRET_ACCESS_KEY=${AWS_CREDENTIAL[1]}
export AWS_SESSION_TOKEN=${AWS_CREDENTIAL[2]}

echo "IAM user/role used to call the operation."
aws sts get-caller-identity
