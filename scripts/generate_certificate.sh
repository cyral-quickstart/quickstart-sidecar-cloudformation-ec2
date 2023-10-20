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


function generate_certificates () {
    KEY_SIZE=4096
    CERT_DURATION=365000
    CERT_COUNTRY="US"
    CERT_PROVINCE="CA"
    CERT_LOCALITY="Redwood City"
    CERT_ORGANIZATION="Cyral Inc."
    CERT_HOST=$1
    CLIENT_CERT_SECRET_ID=$2
    CA_CERT_SECRET_ID=$3
    region=$4
    TMP_CERT_DIR="./"
    CA_KEY_FILE="$TMP_CERT_DIR/key-ca.pem"
    CA_CERT_FILE="$TMP_CERT_DIR/cert-ca.pem"
    CLIENT_KEY_FILE="$TMP_CERT_DIR/key-tls.pem"
    CLIENT_CERT_FILE="$TMP_CERT_DIR/cert-tls.pem"
    CLIENT_REQ_FILE="$TMP_CERT_DIR/req-tls.csr"
    openssl genrsa $KEY_SIZE > $CA_KEY_FILE
    openssl req -new -x509 -nodes -days $CERT_DURATION -key $CA_KEY_FILE -out $CA_CERT_FILE -subj "/C=$CERT_COUNTRY/ST=$CERT_PROVINCE/L=$CERT_LOCALITY/O=$CERT_ORGANIZATION/CN=$CERT_HOST" -addext "keyUsage = keyCertSign, cRLSign" -addext "basicConstraints = CA:TRUE" -addext "subjectKeyIdentifier = hash" -addext "authorityKeyIdentifier = keyid:always"
    openssl req -newkey rsa:$KEY_SIZE -nodes -keyout $CLIENT_KEY_FILE -out $CLIENT_REQ_FILE -subj "/C=$CERT_COUNTRY/ST=$CERT_PROVINCE/L=$CERT_LOCALITY/O=$CERT_ORGANIZATION/CN=$CERT_HOST" -addext "subjectAltName = DNS:$CERT_HOST" -addext "keyUsage = digitalSignature" -addext "extendedKeyUsage = serverAuth" -addext "basicConstraints = CA:FALSE" -addext "subjectKeyIdentifier = hash"
    openssl x509 -req -days $CERT_DURATION -set_serial 01 -in $CLIENT_REQ_FILE -out $CLIENT_CERT_FILE -CA $CA_CERT_FILE -CAkey $CA_KEY_FILE
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

# Check to make sure openssl is installed
if ! command -v openssl &> /dev/null; then
  echo "Please install OpenSSL first"
  exit 1
fi

# Check to make sure your openssl version supports addext
detected_openssl_version=$(openssl req -help 2>&1|grep addext)

if [ -z "$detected_openssl_version" ]; then
    echo "Please upgrade your OpenSSL to a version that supports the addext flag"
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
generate_certificates $SIDECAR_NAME $SidecarCreatedCertificateSecretArn $SidecarCACertificateSecretArn $aws_region