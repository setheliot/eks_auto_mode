#!/bin/bash

# Functions ==================

# Function to check if S3 bucket exists and is writable
check_s3_bucket() {
    if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$BE_REGION" 2>/dev/null; then
        # Try to write a test file
        TEST_FILE="s3://$BUCKET_NAME/test-write-$(date +%s)"
        if echo "test" | aws s3 cp - "$TEST_FILE" --region "$BE_REGION" >/dev/null 2>&1; then
            aws s3 rm "$TEST_FILE" --region "$BE_REGION" >/dev/null 2>&1
            echo "✅ S3 bucket '$BUCKET_NAME' exists and is writable."
        else
            echo "❌ S3 bucket '$BUCKET_NAME' exists but is NOT writable."
            BACKEND_ISOK=false
        fi
    else
        echo "❌ S3 bucket '$BUCKET_NAME' does NOT exist."
        BACKEND_ISOK=false
    fi
}

# Function to check if DynamoDB table exists and is writable
check_dynamodb_table() {
    if aws dynamodb describe-table --table-name "$DDB_TABLE_NAME" --region "$BE_REGION" >/dev/null 2>&1; then
        # Try to write a test item
        TEST_ITEM="{\"LockID\": {\"S\": \"test-lock-$(date +%s)\"}}"
        if aws dynamodb put-item --table-name "$DDB_TABLE_NAME" --item "$TEST_ITEM" --region "$BE_REGION" >/dev/null 2>&1; then
            aws dynamodb delete-item --table-name "$DDB_TABLE_NAME" --key "{\"LockID\": {\"S\": \"test-lock-$(date +%s)\"}}" --region "$BE_REGION" >/dev/null 2>&1
            echo "✅ DynamoDB table '$DDB_TABLE_NAME' exists and is writable."
        else
            echo "❌ DynamoDB table '$DDB_TABLE_NAME' exists but is NOT writable."
            BACKEND_ISOK=false
        fi
    else
        echo "❌ DynamoDB table '$DDB_TABLE_NAME' does NOT exist."
        BACKEND_ISOK=false
    fi
}

# ====================================

IS_SETH=false

if [[ "$1" == "-seth" ]]; then
    IS_SETH=true
fi

###
# Verify user is targeting the correct AWS account
###

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install AWS CLI and try again."
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Terraform is not installed. Please install Terraform and try again."
    exit 1
fi


# Get AWS Account ID using STS
AWS_ACCOUNT=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null)

# Check if AWS_ACCOUNT is empty (invalid credentials)
if [[ -z "$AWS_ACCOUNT" || "$AWS_ACCOUNT" == "None" ]]; then
    echo "There are no valid AWS credentials. Please update your AWS credentials to target the correct AWS account."
    exit 1
fi

# Prompt the user for confirmation
echo -e "\nYour EKS cluster will deploy to AWS account ===> ${AWS_ACCOUNT} <===. Is that what you want?\n"
echo "**** You MUST ensure this is NOT a production account and is NOT currently in use for any business purpose ****"
echo "**** This script and Terraform configuration will perform write and create operations on this account.     ****"
echo "**** If you are unsure, then do NOT proceed                                                                ****"
read -r -p "Proceed? [y/n]: " response

# Check if response is "y" or "yes"
if [[ ! "$response" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    echo "Please update your AWS credentials to target the correct AWS account, and then re-run this script.    "
    exit 1
fi

echo "Proceeding with deployment..."


###
# Verify if backend state is setup and accessible.
###

# Find the terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
REPO_DIR=$(dirname "$SCRIPT_DIR")
TF_DIR="$REPO_DIR/terraform"
cd $TF_DIR


# Extract backend configuration from backend.tf
BACKEND_FILE="./backend.tf"

# Parse S3 bucket name
BUCKET_NAME=$(awk -F'"' '/bucket/{print $2}' "$BACKEND_FILE" | xargs)
DDB_TABLE_NAME=$(awk -F'"' '/dynamodb_table/{print $2}' "$BACKEND_FILE" | xargs)
BE_REGION=$(awk -F'"' '/region/{print $2}' "$BACKEND_FILE" | xargs)

if [[ -z "$BUCKET_NAME" || -z "$DDB_TABLE_NAME" || -z "$BE_REGION" ]]; then
    echo "❌ Error: Unable to parse backend configuration from $BACKEND_FILE"
    exit 1
elif [[ "$IS_SETH" == "false" && "$BUCKET_NAME" == "terraform-state-bucket-eks-auto-uniqueid" ]]; then
    echo "❌ Error: Please update the backend configuration in $BACKEND_FILE with a UNIQUE bucket name."
    exit 1
else
    echo "✅ Backend configuration parsed successfully."
    echo "🪣 S3 bucket name: $BUCKET_NAME"
    echo "📋 DynamoDB table name: $DDB_TABLE_NAME"
    echo "🌎 Region: $BE_REGION - Used for backend state (where S3 bucket and DynamoDb table are)"
    echo "                        Actual EKS cluster region may be different"
fi


# Run checks of backend state
echo "========================="
echo "Checking backend state..."

BACKEND_ISOK=true

check_s3_bucket
check_dynamodb_table

if [[ "$BACKEND_ISOK" == "false" ]]; then
    echo "================================================="
    echo "❌ Backend state is NOT setup correctly. Please update the backend configuration in $BACKEND_FILE."
    echo "👉 You need to create a S3 bucket and a DynamoDB table in the same region as the EKS cluster."
    echo "👉 Then you need to update $BACKEND_FILE with the new S3 bucket name"
    echo "👉 Instructions are in the comments section of $BACKEND_FILE."
    echo "================================================="

    exit 1
fi


echo "✅ All checks of Terraform of backend state passed!"

###
# Deploy the cluster
###

echo "========================="
echo "Deploying EKS cluster..."

# List all *.tfvars files in ./environment/ with numbered options
ENV_DIR="./environment"
TFVARS_FILES=($(ls -1 "$ENV_DIR"/*.tfvars 2>/dev/null))  # Store files in an array

# Check if there are any .tfvars files
if [[ ${#TFVARS_FILES[@]} -eq 0 ]]; then
    echo "❌ No .tfvars files found in $ENV_DIR. Please add environment files and try again."
    exit 1
fi

# Display the available environment files with numbers
echo "Available environments:"
for i in "${!TFVARS_FILES[@]}"; do
    echo "$((i+1)). ${TFVARS_FILES[$i]##*/}"  # Show just the filename
done

# Prompt the user to select an environment
read -r -p "Select a number: " choice

# Validate user input
if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#TFVARS_FILES[@]} )); then
    echo "❌ Invalid selection. Please enter a valid number."
    exit 1
fi

# Get the selected tfvars file
TFVARS_FILE="${TFVARS_FILES[$((choice-1))]}"

# Extract env_name from the selected file
ENV_NAME=$(awk -F'"' '/env_name/ {print $2}' "$TFVARS_FILE" | xargs)
REGION=$(awk -F'"' '/aws_region/  {print $2}' "$TFVARS_FILE" | xargs)

if [[ -z "$ENV_NAME" ]]; then
    echo "❌ Could not extract env_name from $TFVARS_FILE. Ensure the file is correctly formatted."
    exit 1
elif [[ -z "$REGION" ]]; then
    echo "❌ Could not extract aws_region from $TFVARS_FILE. Ensure the file is correctly formatted."
    exit 1
fi

echo "✅ Selected environment: $ENV_NAME to deploy to AWS Region $REGION (from $(basename "$TFVARS_FILE"))"
read -r -p "Is this correct? [y/n]: " response

# Check if response is "y" or "yes"
if [[ ! "$response" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    echo "🛑 Please check your $TFVARS_FILE configuration and try again."
    exit 1
fi

echo "🏃 Running terraform init..."
if ! terraform init 2> terraform_init_err.log; then
    if grep -q "Error refreshing state: state data in S3 does not have the expected content." terraform_init_err.log; then
        echo "👍 Ignoring known state data error and continuing..."
    else
        echo "❌ Unexpected error occurred. Exiting."
        exit 1
    fi 
fi

if [ -f terraform_init_err.log ]; then
    rm terraform_init_err.log
fi

# Check the current Terraform workspace
CURRENT_WS=$(terraform workspace show 2>/dev/null)

if [[ "$CURRENT_WS" != "$ENV_NAME" ]]; then
    echo "🔄 Switching to Terraform workspace: $ENV_NAME"
    
    # Check if the workspace exists
    if ! terraform workspace select "$ENV_NAME" 2>/dev/null; then
        echo "📋 Workspace '$ENV_NAME' does not exist. Creating it..."
        terraform workspace new "$ENV_NAME"
    fi
fi

# Run Terraform apply
echo "🚀 Running Terraform apply..."
terraform apply -auto-approve -var-file="$TFVARS_FILE"


