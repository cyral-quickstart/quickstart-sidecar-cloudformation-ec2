# Configuring certificates for Cloudformation AWS EC2 sidecars

You can use Cyral's default [sidecar-created
certificate](https://cyral.com/docs/sidecars/deployment/certificates#sidecar-created-certificate) or use a
[custom certificate](https://cyral.com/docs/sidecars/deployment/certificates#custom-certificate) to secure
the communications performed by the sidecar.

In this page, we discuss the various certificate scenarios and their deployment instructions. Please refer to the [Sidecar certificate types](https://cyral.com/docs/sidecars/deployment/certificates#sidecar-certificate-types) documentation to understand the certificates used by the sidecar.

## Deployment Scenarios

There are several different deployment scenarios when it comes to certificates and the sidecar. Some are more suitable for a POC deployment, while others are geared more towards a production deployment.

### Sidecar Created Certificates

This method is more suitable for POC deployments as each sidecar instance will generate its own custom certificates.

In this deployment scenario, each sidecar instance will generate its own self signed certificates during deployment. These certificates are NOT shared between instances in deployments where the sidecar is scaled to 2 or more instances.

This scenario is the default behavior for a sidecar deployment if you do not supply any custom certificates via the `LoadBalancerCertificateArn` template parameter or by creating the secrets listed below.

### Custom Certificates Provided During Deployment

This method is suitable for both POC and production deployments as the certificates are shared across multiple instances.

In this deployment scenario, you must first generate your own self signed certificates using the [Generating Self Signed Certificates](#generate_self_signed) or [Importing Existing Certificates](#importing_existing) instructions below. These instructions will allow you to store the certificates in AWS secrets that are accessible by all sidecar instances in the deployment. The imported certificates are shared between instances in deployments where the sidecar is scaled to 2 or more instances.

### Custom Certificate Deployed on an AWS Load Balancer

This method can be suitable for both POC and production deployments as the certificates reside on the AWS Loadbalancer are do not need to be shared between sidecar instances.

In this deployment method, you must first [request a public ceritificate](https://docs.aws.amazon.com/acm/latest/userguide/gs.html) or [import an existing certificate](https://docs.aws.amazon.com/acm/latest/userguide/import-certificate.html) using the AWS Certificate Manager. Once the certificate has been imported into the AWS Certificate Manager, then you enter the ceriticate's ARN into the `LoadBalancerCertificateArn` parameter in the [cft_sidecar.yaml](../cft_sidecar.yaml).

> [!IMPORTANT]
> This deployment scenario will only use the certificate for HTTPS related repos like S3 (using the Cyral S3 browser) and Snowflake. All other TLS connections will be handled by the certificates generated or deployed with the sidecar.

## Use your own certificate

You can use a certificate signed by you or the Certificate Authority of your
choice. Provide the ARN of the certificate secrets to the sidecar module, as
in the section [Provide custom certificate to the sidecar](#provide-custom-certificate-to-the-sidecar). 
Please make sure
that the following requirements are met by your private key / certificate pair:

- Both the private key and the certificate **must** be encoded in the **UTF-8**
  charset.

- The certificate must follow the **X.509** format.

**WARNING:** *Windows* commonly uses UTF-16 little-endian encoding. A UTF-16 certificate
   or private key will *not* work in the sidecar.

## Cross-account deployment

If you have a scenario in which you have two different accounts: one where you
deploy the sidecar and another where you manage the sidecar secrets, then you
can use the module inputs
`SidecarTLSCertificateRoleArn` (for TLS certificate) or
`SidecarCACertificateRoleArn` (for CA certificate) to the sidecar
module. Suppose you have the following configuration:

   - Account `111111111111` used to manage secrets
   - Account `222222222222` used to deploy the sidecar

1. You need to manually configure at least one IAM role to allow for
   cross-account access: a role in `111111111111`, which we will call
   `role1`. `role1` must have a trust policy that allows the sidecar role to assume it. If you create `role2`, note that it
   must allow `sts:AssumeRole` on `role1`. This configuration can be achieved in
   different ways, so we direct you to [AWS
   documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html)
   for further information.

2. Provide the ARN of `role1` to `SidecarTLSCertificateRoleArn` (for the TLS
   certificate) or `SidecarCACertificateRoleArn` (for the CA certificate) of
   the sidecar module.

3. Provide the ARNs of the certificate secrets to the sidecar module, as
   instructed in the next section.

## Provide custom certificate to the sidecar

There are two parameters in the sidecar module you can use to provide the ARN of
a secret containing a custom certificate:

1. `SidecarTLSCertificateRoleArn` (Optional) ARN of secret in AWS Secrets
   Manager that contains a certificate to terminate TLS connections.

1. `SidecarCACertificateRoleArn` (Optional) ARN of secret in AWS Secrets
   Manager that contains a CA certificate to sign sidecar-generated certs.

The secrets must follow the following JSON format.

```json
{
  "cert": "{myCertBase64}",
  "key": "{myPrivateKeyBase64}"
}
```

Where `{myCertBase64}` is your custom certificate, encoded in base64, and
`{myPrivateKeyBase64}` is your private key, encoded in base64. Note that the
base64 encoding is an extra encoding over the PEM-encoded values.

The choice between providing a `tls`, a `ca` secret or *both* will depend on the repositories
used by your sidecar. See the certificate type used by each repository in the 
[sidecar certificates](https://cyral.com/docs/sidecars/deployment/certificates#sidecar-certificate-types) page.

## <a name="generate_self_signed"/>Generating Self Signed Certificates

If you do not have an internal CA or would prefer to use self-signed certificates, you can make use of the [generate_certificates.sh](../scripts/generate_certificates.sh) script included in this repo. This is a simple bash script that will generate a CA certificate and TLS certificate that can be used by the sidecar. The script will create the certificates as secrets in your AWS account with the following names:

* `/cyral/sidecars/${SidecarId}/ca-certificate`
* `/cyral/sidecars/${SidecarId}/self-signed-certificate`

This script expects a few environment variables to be set:

* `AWS_DEFAULT_REGION` : This should be set to the same region where you plan to deploy your sidecar
* `SIDECAR_ID` : This should be set to the same value you use for the `SidecarId` parameter of this [Cloudformation](../cft_sidecar.yaml) template
* `SIDECAR_NAME` : (Optional) This should be set to the same value you use for the `SidecarDNSName` parameter of this [Cloudformation](../cft_sidecar.yaml) template. If this is not set, then the default hostname of `sidecar.cyral.app.com` will be used for the domain name on the certificates.

### Required commands

This script makes use of the following commands:

* [jq](https://jqlang.github.io/jq/)
* [AWS CLI](https://aws.amazon.com/cli/)
* [OpenSSL](https://www.openssl.org/) - This uses the `addext` feature of OpenSSL so you will need at least version `1.1.1` or greater.

### Generating the Certificate

With the environment variables set, you can run the command to generate the certificates and create the AWS secrets. The ARN for each of the certificates are listed in the results.

The ARN (`arn:aws:secretsmanager:us-east-1:222222222222:secret:/cyral/sidecars/abc123/ca-certificate-CC293L`) for the AWS Secret named `/cyral/sidecars/abc123/ca-certificate` should be used as the value for the `SidecarCACertificateSecretArn` [Cloudformation](../cft_sidecar.yaml) template parameter.

The ARN (`arn:aws:secretsmanager:us-east-1:222222222222:secret:/cyral/sidecars/abc123/self-signed-certificate-A27IAy`) for the AWS Secret named `/cyral/sidecars/abc123/self-signed-certificate` should be used as the value for the `SidecarCreatedCertificateSecretArn` [Cloudformation](../cft_sidecar.yaml) template parameter.


```shell
% ./generate_certificates.sh 
..+....+......+...........+.........+.+...+++++++++++++++++++++++++++++++++++++++++++++*......+..+..........+........+....+.....+.+............+++++++++++++++++++++++++++++++++++++++++++++*.....+...+..+....+.....+..........+......+...+.....+.......+......+.....+..........+..+.+...........+.........+...............+............+...+................+.........+..+....+...........+...................+........+.+.....+.+...+..+...+.............+............+........+....+...+......+.....+.+.........+..+.........+.........+......+.............+...+.........+......+...............+.........+.....+..................+..........+.....+................+..+.......+..+.+........+......+.............+...+...+..+............+...............+.......+.....+...+.......+.....+...+......................+..............+......+......+.......+....................+.......+...+..+.+...+.....+.+......+.....+..................+....+........+...+......+...+.+.........+.....+......+..........+.....+....+...+........+.......+..+.....................+.+.....+....+...............+..+....+.........+.........+......+.....+....+.......................+.......+........+...............+.......+..+.+..+............+...+.......+......+..+.......+...+..+.+.......................+......+.............+++++
....+...+.+.........+...+..+.+..+....+++++++++++++++++++++++++++++++++++++++++++++*..+..+.+..+...+...............+.+...+..+.....................+.......+..+......+.......+........+...+.+++++++++++++++++++++++++++++++++++++++++++++*.........+......+...........+......+...+.......+............+.....+......+.........+......+................+...+..+....+..+..........+.........+.........+.....+.......+...+..+....+...+.....+......+.+.....+...+..........+........+..................+....+...+....................+...+.......+...+..............+.+........................+...................................+...+......................+...+........+......+...+......+.+..............+.+...+..+......+.............+..+............+.+..+............+.....................+.+.....+...+............+.+..+......+....+........+...+.+.................................+...........+.+...+.....+.............+...+.....+......+......+...+......+.+..+..................+......................+...........+.+..............+.+........+.............+.....+....+........+...+...+..........+............+.......................+....+...+.........+........................+....................+..........+..+...+....+.....+.+.....................+.......................+............+....+..+.......+..........................+....+......+...............+......+........+...+....+.....+..........+........+.+.....+......+.+........+.......+..............+.............+......+.....+....+...........+..........+.....+......+......+....+.............................+....+........+.......+............+........+..........+.....+............+....+.......................................+...+..+............................+.........+.....+.+...+...........+......+.......+..+...+...+.......+..+...................+..+.......+..+..........+.............................+.........+.+......+......+..+...+.............+............+..+.+..+............+......+.+.........+..+...........................+.+..+....+......+.......................+......+......+.......+.....+..........+...+..............+.+.........+......+.....+....+...........+....+......+........+.......+..+...+............+.......+++++
-----
Certificate request self-signature ok
subject=C = US, ST = CA, L = Redwood City, O = Cyral Inc., CN = sidecar.app.cyral.com
{
    "ARN": "arn:aws:secretsmanager:us-east-1:222222222222:secret:/cyral/sidecars/abc123/ca-certificate-CC293L",
    "Name": "/cyral/sidecars/abc123/ca-certificate",
    "VersionId": "abc123...xyz789",
    "VersionStages": [
        "AWSCURRENT"
    ]
}
{
    "ARN": "arn:aws:secretsmanager:us-east-1:222222222222:secret:/cyral/sidecars/abc123/self-signed-certificate-A27IAy",
    "Name": "/cyral/sidecars/abc123/self-signed-certificate",
    "VersionId": "abc123...xyz789",
    "VersionStages": [
        "AWSCURRENT"
    ]
}
```

## <a name="importing_existing"/>Importing Existing Certificates

If you already have an internal CA and would prefer to certificates generated by your CA, you can make use of the [import_certificates.sh](../scripts/import_certificates.sh) script included in this repo. This is a simple bash script that will import your CA certificate and TLS certificate that can be used by the sidecar. The script will import the certificates as secrets in your AWS account with the following names:

* `/cyral/sidecars/${SidecarId}/ca-certificate`
* `/cyral/sidecars/${SidecarId}/self-signed-certificate`

This script expects a few environment variables to be set:

* `AWS_DEFAULT_REGION` : This should be set to the same region where you plan to deploy your sidecar
* `SIDECAR_ID` : This should be set to the same value you use for the `SidecarId` parameter of this [Cloudformation](../cft_sidecar.yaml) template

The script expects the following files to be present in the directory where you execute the `import_certificates.sh` command:

* `key-ca.pem` : This is the private key in pem format for your generated CA certificate
* `cert-ca.pem` : This is the certificate in pem format for your generated CA certificate
* `key-tls.pem` : This is the private key in pem format for your generated TLS certificate
* `cert-tls.pem` : This is the certificate in pem format for your generated TLS certificate

### Required commands

This script makes use of the following commands:

* [jq](https://jqlang.github.io/jq/)
* [AWS CLI](https://aws.amazon.com/cli/)

### Importing the Certificate

With the environment variables set and files created, you can run the command to import the certificates and create the AWS secrets. The ARN for each of the certificates are listed in the results.

The ARN (`arn:aws:secretsmanager:us-east-1:222222222222:secret:/cyral/sidecars/abc123/ca-certificate-CC293L`) for the AWS Secret named `/cyral/sidecars/abc123/ca-certificate` should be used as the value for the `SidecarCACertificateSecretArn` [Cloudformation](../cft_sidecar.yaml) template parameter.

The ARN (`arn:aws:secretsmanager:us-east-1:222222222222:secret:/cyral/sidecars/abc123/self-signed-certificate-A27IAy`) for the AWS Secret named `/cyral/sidecars/abc123/self-signed-certificate` should be used as the value for the `SidecarCreatedCertificateSecretArn` [Cloudformation](../cft_sidecar.yaml) template parameter.


```shell
% ./import_certificate.sh 
{
    "ARN": "arn:aws:secretsmanager:us-east-1:222222222222:secret:/cyral/sidecars/abc123/ca-certificate-CC293L",
    "Name": "/cyral/sidecars/abc123/ca-certificate",
    "VersionId": "abc123...xyz789",
    "VersionStages": [
        "AWSCURRENT"
    ]
}
{
    "ARN": "arn:aws:secretsmanager:us-east-1:222222222222:secret:/cyral/sidecars/abc123/self-signed-certificate-A27IAy",
    "Name": "/cyral/sidecars/abc123/self-signed-certificate",
    "VersionId": "abc123...xyz789",
    "VersionStages": [
        "AWSCURRENT"
    ]
}
```
