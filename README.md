# Sidecar - CloudFormation AWS EC2

A quick start to deploy a sidecar to AWS EC2 using CloudFormation!

## Architecture

![Deployment architecture](images/aws_architecture.png)

## Deployment

The elements shown in the architecture diagram above are deployed by the [Cyral sidecar CloudFormation module for AWS EC2](https://github.com/cyralinc/sidecar-cloudformation-ec2/). The module requires existing VPC and subnets in order to create the necessary components for the sidecar to run. In a high-level, these are the resources deployed:

* EC2
    * Auto scaling group (responsible for managing EC2 instances and EBS volumes)
    * Network load balancer
    * Security group
* Secrets Manager
    * Sidecar credentials
    * Sidecar CA certificate
    * Sidecar self-signed certificate
* IAM
    * Sidecar role
* Cloudwatch
    * Log group (optionally created)

### Requirements

* Make sure you have access to your AWS environment with an account that has sufficient permissions to deploy the sidecar. The minimum permissions must allow for the creation of the elements listed previously. We recommend Administrator permissions (`AdministratorAccess` policy) as the module creates an IAM role.

### Examples

#### Quick Start

* Download the deployment template in [cft_sidecar.yaml](./cft_sidecar.yaml).
* Log in to AWS and open the [CloudFormation console](http://console.aws.amazon.com/cloudformation/home).
    * Create a new stack.
    * Upload the downloaded template.
    * Click `Next`.
    * Enter a suitable `Stack name`, then fill the parameters `SidecarId`, `ControlPlane`, `ClientId` and 
    `ClientSecret` with the information from the `Cyral Templates` option
    in the `Deployment` tab of your sidecar details.
    * Fill the parameters `VPC` and `Subnets` with an existing VPC and
    subnet that can connect to the database you plan to protect with this
    sidecar.
    * Set parameters `AssociatePublicIpAddress=true` and `LoadBalancerScheme='internal'`
    to deploy a public sidecar.
    * Click `Next`, follow the remaining steps of the wizard acknowledging the capabilities requested and confirm the stack creation.

This quick start will create the simplest configuration possible on your AWS account
and deploy a single sidecar instance behind the load balancer. As this is just an example
to help you understand basic concepts, it deploys a public sidecar instance with an
internet-facing load balancer.

Deploying a test sidecar in a public configuration is the easiest way to have all the components
in place and understand the basic concepts of our product as a public sidecar will easily
communicate with the SaaS control plane.

In case the databases you are protecting with the Cyral sidecar also live on AWS, make sure to
add the sidecar security group (see output parameter `SidecarSecurityGroupID`) to the list of
allowed inbound rules in the databases' security groups. If the databases do not live on AWS,
analyze what is the proper networking configuration to allow connectivity from the EC2
instances to the protected databases.

#### Production Starting Point

* Download the deployment template in [cft_sidecar.yaml](./cft_sidecar.yaml).
* Log in to AWS and open the [CloudFormation console](http://console.aws.amazon.com/cloudformation/home).
    * Create a new stack.
    * Upload the downloaded template.
    * Click `Next`.
    * Enter a suitable `Stack name`, then fill the parameters `SidecarId`, `ControlPlane`, `ClientId` and 
    `ClientSecret` with the information from the `Cyral Templates` option
    in the `Deployment` tab of your sidecar details.
    * Fill the parameters `VPC` and `Subnets` with an existing VPC and
    subnet that can connect to the database you plan to protect with this
    sidecar.
    * Set `AssociatePublicIpAddress=true`, `LoadBalancerScheme='internal'`, `AsgMin=1`, `AsgMax=4`, 
    `AsgDesired=2`, and `EnableCrossZoneLoadBalancing=true`.
    * Click `Next`, follow the remaining steps of the wizard acknowledging the capabilities requested and confirm the stack creation.

```yaml

```

The example above will create a production-grade configuration and assumes you understand
the basic concepts of a Cyral sidecar.

For a production configuration, we recommend that you provide multiple subnets in different
availability zones and properly assess the dimensions and number of EC2 instances required
for your production workload.

In order to properly secure your sidecar, define appropriate inbound CIDRs using variables
`SSHInboundCIDR`, `DBInboundCIDR` and `MonitoringInboundCIDR`. See the
variables documentation in the downloaded file for more information.

In case the databases you are protecting with the Cyral sidecar also live on AWS, make sure to
add the sidecar security group (see output parameter `SidecarSecurityGroupID`) to the list of
allowed inbound rules in the databases' security groups. If the databases do not live on AWS,
analyze what is the proper networking configuration to allow connectivity from the EC2
instances to the protected databases.

### Parameters

See the full list of parameters in the parameters section of the [deployment template](./cft_sidecar.yaml).

### Upgrade

This quick start supports [1-click upgrade](https://cyral.com/docs/sidecars/manage/upgrade#1-click-upgrade).

To enable the 1-click upgrade feature, leave the variable `SidecarVersion` empty and upgrade
the sidecar from Cyral control plane.

If you prefer to block upgrades from the Cyral control plane and use a **static version**, assign
the desired sidecar version to `SidecarVersion`. To upgrade your sidecar, update this parameter
with the target version and upgrade the CloudFormation stack.

Learn more in the [sidecar upgrade procedures](https://cyral.com/docs/sidecars/manage/upgrade) page.

### Advanced

Instructions for advanced deployment configurations are available for the following topics:

* [Sidecar certificates](./docs/certificates.md)
* [Sidecar instance metrics](./docs/metrics.md)
