# Bring Your Own Secret

You can create your own secret and provide it as an input parameter instead of
letting the template manage the sidecar secrets automatically. This is tipically
useful for customers willing to deploy the secrets to a different account
than that used to deploy the sidecar.

You can create your own secret in AWS Secrets Manager and provide its full
ARN to parameter `SecretArn` as long as the secrets contents is a JSON
with the following format:

```JSON
{
    "clientId":"",
    "clientSecret":"",
    "idpCertificate":"",
    "sidecarPrivateIdpKey":"",
    "sidecarPublicIdpCertificate":""
}
```

| Attribute                     | Required | Format |
| :---------------------------- | :------: | ------ |
| `clientId`                    | Yes      | String |
| `clientSecret`                | Yes      | String |
| `idpCertificate`              | No       | String - new lines escaped (replace `\n` by `\\n``) |
| `sidecarPrivateIdpKey`        | No       | String - new lines escaped (replace `\n` by `\\n``) |
| `sidecarPublicIdpCertificate` | No       | String - new lines escaped (replace `\n` by `\\n``) |

Make sure to escape new line characters by replacing `\n` by `\\n` in the parameters `idpCertificate`,
`sidecarPublicIdpCertificate` and `sidecarPrivateIdpKey` before storing them on
your secret.

In case you are creating this secret in a different account, use the input
parameter `SecretRoleArn` to provide the ARN of the role that will be
assumed in order to read the secret.

See also:

* To understand the concept of `Full ARN`, read [this page](https://docs.aws.amazon.com/secretsmanager/latest/userguide/troubleshoot.html#ARN_secretnamehyphen).