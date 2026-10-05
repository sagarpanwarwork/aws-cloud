# Lab Network Configuration

`aws ec2 describe-regions --query "Regions[].RegionName" --output table`

## Get AMI

`aws ssm get-parameter  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64   --query "Parameter.Value"   --output text --region ap-south-1`

## List subnets:

`aws ec2 describe-subnets --region ap-south-1 --query "Subnets[].{SubnetId:SubnetId,VPC:VpcId,AZ:AvailabilityZone}" --output table`

## Get Security Groups

`aws ec2 describe-security-groups --region ap-south-1 --query "SecurityGroups[].{GroupId:GroupId,VPC:VpcId,Name:GroupName}" --output table`

## Also you can check other availables -

`aws ec2 describe-instance-types --region ap-south-1 --query "InstanceTypes[].InstanceType" --output table`

`aws ec2 describe-security-groups --region ap-south-1 --query 'SecurityGroups[0].[GroupId,VpcId,GroupName]' --output table`

`aws ec2 describe-subnets --region ap-south-1 --query 'Subnets[0].[SubnetId,VpcId,AvailabilityZone]' --output table`

# Test 1 — Attempt to Pass AdminRole
Command:
`aws ec2 run-instances --image-id ami-08e3b3155fc937a94 --instance-type t3.micro --subnet-id subnet-008c3637fce824885 --security-group-ids sg-086fef94098a595dc --iam-instance-profile Name=AdminRole --region ap-south-1 --dry-run`

# Test 2 — Pass AppServer-WebRole
Command:
`aws ec2 run-instances --image-id ami-08e3b3155fc937a94 --instance-type t3.micro --subnet-id subnet-008c3637fce824885 --security-group-ids sg-086fef94098a595dc --iam-instance-profile Name=AppServer-WebRole --region ap-south-1 --dry-run`
