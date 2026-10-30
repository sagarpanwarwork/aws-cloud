### 
The lab will create:
- VPC, two Availability Zones and public subnets.
- Application Load Balancer and target group.
- Two EC2 instances through an Auto Scaling Group, with capacity up to four.
- IAM instance role and Systems Manager access. No SSH key required.
- CloudWatch Agent for application logs, memory and disk metrics.
- SNS notification topic.
- Detailed EC2 monitoring and Auto Scaling group metrics.
- Optional Terraform-managed target-tracking policy and 5xx alarm.

### Copy the example configuration:
`p terraform.tfvars.example terraform.tfvars`

### Initialize and validate:
`terraform init`
`terraform fmt -recursive`
`terraform validate`

### Review and deploy:
`terraform plan -out=tfplan`
`terraform apply tfplan`

The default deployment creates two EC2 instances, with an ASG capacity range of 2–4.

### Once deployment finishes:
`terraform output`

### open the application
`terraform output -raw application_url`

### Test the app
`APP_URL=$(terraform output -raw application_url)`

`curl "$APP_URL/error"`

Expected response: HTTP 500.