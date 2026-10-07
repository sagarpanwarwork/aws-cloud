# Attempt to assume without ExternalId (Fails)
aws sts assume-role \
  --role-arn "arn:aws:iam::222222222222:role/Prod-S3-Operator-Role" \
  --role-session-name "CrossAccountTest"

# Result: An error occurred (AccessDenied) when calling the AssumeRole operation.

# Assume role with valid ExternalId (Succeeds)
aws sts assume-role \
  --role-arn "arn:aws:iam::222222222222:role/Prod-S3-Operator-Role" \
  --role-session-name "CrossAccountTest" \
  --external-id "ClassroomCrossAccountSecret123"