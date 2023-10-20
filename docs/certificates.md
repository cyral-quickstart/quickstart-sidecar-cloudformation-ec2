# Configuring certificates for Cloudformation AWS EC2 sidecars

You can use Cyral's default [sidecar-created
certificate](https://cyral.com/docs/sidecars/certificates/overview#sidecar-created-certificate) or use a
[custom certificate](https://cyral.com/docs/sidecars/certificates/overview#custom-certificate) to secure
the communications performed by the sidecar. In this page, we provide
instructions on how to use a custom certificate.

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

## Generating Self Signed Certificates

If you do not have an internal CA or would prefer to use self-signed certificates, you can make use of the [generate_certificate.sh](../scripts/generate_certificate.sh) script included in this repo. This is a simple bash script that will generate a CA certificate and TLS certificate that can be used by the sidecar. The script will create the certificates as secrets in your AWS account with the following names:

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
% ./generate_certificate.sh 
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