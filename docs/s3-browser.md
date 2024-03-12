#### Enable the S3 File Browser

To configure the sidecar to work on the S3 File Browser, set the following parameters in your CloudFormation stack:

  - `SidecarDNSName`: Add the sidecar custom CNAME.
  - `LoadBalancerCertificateArn`: Add the ARN of the TLS certificate in
    AWS Certificate Manager.

For sidecars with support for S3, it is also necessary to create an IAM
role with permissions to access the target S3 buckets. This role must
have a trust relationship with the sidecar role created as part of this template,
so the sidecar can use it to access the target S3 buckets. The arn of the IAM
role with the S3 access permissions must then be provided to the 
control plane as part of the repository configuration.

For more details about the S3 File Browser configuration, check the 
[Enable the S3 File Browser](https://cyral.com/docs/how-to/enable-s3-browser) 
documentation.
