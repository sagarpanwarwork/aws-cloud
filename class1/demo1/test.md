# Phase 1 TEST 1

`aws s3 ls`
Result - displays s3 buckets - Right now, I am logged in as an Administrator. 

Production applications should never run using long-lived admin credentials. We will now assume a temporary, restricted role. 

`aws sts assume-role --role-arn "arn:aws:iam::YOUR_ACCOUNT_ID:role/DevOps-Operator-Role" --role-session-name "ClassroomDemoSession"`


AWS returns temporary credentials valid for 1 hour (you can increase the validity time of AWS temporary credentials up to 12 hours for IAM roles, Pass the --duration-seconds parameter (in the AWS CLI) ):


{
    "Credentials": {
        "AccessKeyId": "ASIA...",
        "SecretAccessKey": "wJalr...",
        "SessionToken": "FQoG..."
    }
}

`aws sts get-caller-identity`

# Phase 2 TEST 1: Implicit deny default (zero trust)
`aws s3 ls`

An error occurred (AccessDenied) when calling the ListBuckets operation: Access Denied

