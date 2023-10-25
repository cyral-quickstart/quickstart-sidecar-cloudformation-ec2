#!/bin/bash

function create_secret() {
    secret_name="$1"
    secret_description="$2"
    region="$3"
    create_secret_result=$(aws secretsmanager --region $region create-secret --name "$secret_name" --description "$secret_description")
    echo $create_secret_result | jq -r ".ARN"
}

function check_for_secrets() {
    sidecar_id="$2"
    region="$1"
    get_secret_result=$(aws secretsmanager list-secrets --filter Key="name",Values="/cyral/sidecars/$sidedcar_id/ca-certificate,/cyral/sidecars/$sidecar_id/self-signed-certificate" --region $region)
    secrets_list=$(echo $get_secret_result |jq '.SecretList | length')
    if [ $secrets_list -gt 0 ]; then
        echo "Secrets already exist for this sidecar."
        echo "$get_secret_result"
        exit 1
    fi
}

function store_cert_data_in_secret() {
    key_file="$1"
    cert_file="$2"
    cert_secret="$3"
    region="$4"
    key_file_data=$(cat $key_file|base64)
    cert_file_data=$(cat $cert_file|base64)
    escaped_secret_data="{\"key\":\"$key_file_data\",\"cert\":\"$cert_file_data\"}"
    put_secret_value $cert_secret "$escaped_secret_data" $region
}

function put_secret_value() {
  secret_arn="$1"
  escaped_secret_data="$2"
  region="$3"
  [ -z "$secret_arn" ] && return
  (
    aws --region $region secretsmanager put-secret-value --secret-id "$secret_arn" --secret-string "$escaped_secret_data"
  )
}

function check_for_cert_file () {
  if test -f "$1"; then
    return 1
  else
    echo "Could not locate the file : ${1}"
    exit 1
  fi
}

function import_certificates () {
    CLIENT_CERT_SECRET_ID=$2
    CA_CERT_SECRET_ID=$3
    region=$1
    TMP_CERT_DIR="."
    CA_KEY_FILE="$TMP_CERT_DIR/key-ca.pem"
    CA_CERT_FILE="$TMP_CERT_DIR/cert-ca.pem"
    CLIENT_KEY_FILE="$TMP_CERT_DIR/key-tls.pem"
    CLIENT_CERT_FILE="$TMP_CERT_DIR/cert-tls.pem"
    check_for_cert_file $CA_KEY_FILE
    check_for_cert_file $CA_CERT_FILE
    check_for_cert_file $CLIENT_KEY_FILE
    check_for_cert_file $CLIENT_CERT_FILE
    store_cert_data_in_secret $CA_KEY_FILE $CA_CERT_FILE $CA_CERT_SECRET_ID $region
    store_cert_data_in_secret $CLIENT_KEY_FILE $CLIENT_CERT_FILE $CLIENT_CERT_SECRET_ID $region
}

## Main

# Variables

# Check to make sure jq is installed
if ! command -v jq &> /dev/null; then
  echo "Please install jq first"
  exit 1
fi

# Check to make sure the AWS CLI is installed
if ! command -v aws &> /dev/null; then
  echo "Please install the AWS CLI first"
  exit 1
fi

# Check to make sure the environment variables are set
if [ -z "$AWS_DEFAULT_REGION" ]; then
    echo "Please be sure to set your AWS Region Env Var : AWS_DEFAULT_REGION"
    exit 1
fi

# Check to make sure we have a SIDECAR_ID environment variable defined
if [ -z "$SIDECAR_ID" ]; then
    echo "Please set the SIDECAR_ID Env Var to that of the Sidecar ID in the Cyral Control Plane"
    exit 1
fi

# Check if there's a sidecar_name defined.
# - If not, we'll use a generic name when generating the certificates
if [ -z "$SIDECAR_NAME" ]; then
    SIDECAR_NAME="sidecar.app.cyral.com"
fi

# Let's check to make sure we don't already have secrets created
check_for_secrets $AWS_DEFAULT_REGION $SIDECAR_ID

# Create the Secrets in AWS
SidecarCreatedCertificateSecretArn=$(create_secret "/cyral/sidecars/$SIDECAR_ID/self-signed-certificate" 'TLS certificate needed by the sidecar to terminate TLS connections' $AWS_DEFAULT_REGION)
SidecarCACertificateSecretArn=$(create_secret "/cyral/sidecars/$SIDECAR_ID/ca-certificate" 'TLS certificate needed by the sidecar to terminate TLS connections' $AWS_DEFAULT_REGION)

# Generate certificates and store them in the secret
import_certificates $SIDECAR_NAME $SidecarCreatedCertificateSecretArn $SidecarCACertificateSecretArn $aws_region
