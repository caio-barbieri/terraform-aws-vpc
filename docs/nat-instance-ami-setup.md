# NAT Instance AMI Setup Guide

This guide explains how to create and configure a custom AMI for NAT instances before using the `nat_instance` feature in this Terraform module.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Access to AWS account where the AMI will be created
- Permissions to create EC2 instances, AMIs, IAM roles, and modify image attributes

## Overview

NAT instances require a custom AMI with specific configurations. This module uses a `data` source to fetch the AMI, so you must create and configure it before deploying NAT instances.

## Step 1: Create IAM Instance Profile

Create an IAM role and instance profile for SSM access:

```bash
# Create trust policy
cat > /tmp/ec2-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name EC2-SSM-Role \
  --assume-role-policy-document file:///tmp/ec2-trust-policy.json

# Attach SSM policy
aws iam attach-role-policy \
  --role-name EC2-SSM-Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# Create instance profile
aws iam create-instance-profile \
  --instance-profile-name EC2-SSM-Profile

# Add role to instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name EC2-SSM-Profile \
  --role-name EC2-SSM-Role
```

Wait ~10 seconds for the instance profile to propagate.

## Step 2: Launch Base EC2 Instance

Launch an Amazon Linux 2023 instance with SSM access:

```bash
aws ec2 run-instances \
  --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --instance-type t3.micro \
  --iam-instance-profile Name=EC2-SSM-Profile \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=nat-instance-base}]' \
  --region us-east-1
```

Wait for the instance to be running and SSM-ready (~2 minutes).

## Step 3: Configure NAT Instance

Connect to the instance via SSM and run the following commands:

```bash
# Connect to instance
aws ssm start-session --target <INSTANCE_ID> --region us-east-1

# Inside the instance, run:
sudo -i

# Install iptables-services
yum install iptables-services -y
systemctl enable iptables
systemctl start iptables

# Enable IP forwarding (persistent across reboots)
cat > /etc/sysctl.d/custom-ip-forwarding.conf << 'EOF'
net.ipv4.ip_forward=1
EOF

sysctl -p /etc/sysctl.d/custom-ip-forwarding.conf

# Identify primary network interface
netstat -i
# Note the primary interface name (usually eth0, enX0, or ens5)
# Exemplo de saida em teste rodado e, 2026-02-27
# ernel Interface table
# Iface             MTU    RX-OK RX-ERR RX-DRP RX-OVR    TX-OK TX-ERR TX-DRP TX-OVR Flg
# ens5             9001     6995      0      0 0          3997      0      0      0 BMRU
# lo              65536       12      0      0 0            12      0      0      0 LR

# Get the primary interface name automatically
PRIMARY_INTERFACE=$(ip route | grep default | awk '{print $5}')
echo "Primary interface: $PRIMARY_INTERFACE"

# Configure iptables for NAT (using the detected interface)
/sbin/iptables -t nat -A POSTROUTING -o $PRIMARY_INTERFACE -j MASQUERADE
/sbin/iptables -F FORWARD
service iptables save

# Verify the rule was created correctly
iptables -t nat -L POSTROUTING -n -v

# Exit
exit
exit
```

**Source:** [AWS Documentation - Work with NAT instances](https://docs.aws.amazon.com/vpc/latest/userguide/work-with-nat-instances.html)

## Step 4: Create AMI

Create an AMI from the configured instance:

```bash
aws ec2 create-image \
  --instance-id <INSTANCE_ID> \
  --name "nat-instance-$(date +%Y%m%d-%H%M%S)" \
  --description "NAT Instance AMI with IP forwarding and iptables configured" \
  --tag-specifications 'ResourceType=image,Tags=[{Key=Name,Value=nat-instance},{Key=Type,Value=nat},{Key=ManagedBy,Value=manual}]' \
  --region us-east-1
```

Note the AMI ID from the output.

## Step 5: Share AMI (Optional - Multi-Account Setup)

If using the AMI in a different AWS account, share it:

```bash
aws ec2 modify-image-attribute \
  --image-id <AMI_ID> \
  --launch-permission "Add=[{UserId=<TARGET_ACCOUNT_ID>}]" \
  --region us-east-1
```

## Step 6: Configure Terraform Module

The module will automatically fetch the most recent AMI using this pattern:

```hcl
data "aws_ami" "nat_instance" {
  most_recent = true
  owners      = ["self"]  # Or ["<SOURCE_ACCOUNT_ID>"] for shared AMIs

  filter {
    name   = "name"
    values = ["nat-instance-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "tag:Type"
    values = ["nat"]
  }
}
```

## Step 7: Cleanup

After creating the AMI, you can terminate the base instance:

```bash
aws ec2 terminate-instances --instance-ids <INSTANCE_ID> --region us-east-1
```

## AMI Naming Convention

Use this naming pattern for consistency:
- Format: `nat-instance-YYYYMMDD-HHMMSS`
- Example: `nat-instance-20260227-163000`

This allows the Terraform `data` source to always fetch the most recent version.

## Updating the AMI

To update the NAT instance configuration:

1. Launch a new instance from the existing AMI
2. Make your changes
3. Create a new AMI with a newer timestamp
4. Run `terraform apply` - it will automatically use the new AMI for new instances

**Note:** Existing NAT instances won't be replaced automatically. To use the new AMI, you must taint or manually replace the instances.

## Verification

After deployment, verify NAT functionality from a private subnet instance:

```bash
curl -I https://www.google.com
```

You should receive a successful HTTP response.

## Troubleshooting

### NAT not working
- Verify source/destination check is disabled on the NAT instance
- Check security group allows outbound traffic
- Verify route table points to NAT instance ENI
- Check iptables rules: `sudo iptables -t nat -L -n -v`

### AMI not found
- Verify AMI name matches the pattern `nat-instance-*`
- Check AMI is in the correct region
- Verify AMI is shared if using multi-account setup
- Confirm AMI has tag `Type=nat`

## References

- [AWS VPC User Guide - NAT Instances](https://docs.aws.amazon.com/vpc/latest/userguide/work-with-nat-instances.html)
- [AWS EC2 User Guide - Share an AMI](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/sharingamis-explicit.html)
