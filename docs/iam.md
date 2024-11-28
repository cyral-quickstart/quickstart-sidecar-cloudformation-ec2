# Configuring IAM Roles Cloudformation AWS EC2 sidecars

In order for the Sidecar to provide access to AWS resources such as S3 and DynamoDB, the sidecar needs to be granted the `sts:AssumeRole` action on roles that grant users access to AWS related repositories such as:

* S3
* DynamoDB
* RDS instances using IAM based authentication

Granting the `sts:AssumeRole` action is a manual step that must be performed after you have deployed your sidecar. You can refer to the [Make AWS IAM role settings](https://cyral.com/docs/manage-repositories/s3/s3-sso/#make-aws-iam-role-settings) section of the `SSO for S3` page in the [Cyral Docs](https://cyral.com/docs) for additional details.