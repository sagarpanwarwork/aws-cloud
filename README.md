# AWS - Amazon Web Services

## 001 What does this mean - protocol    = "-1"
The use of -1 is an inherited convention from low-level networking, directly mapped into the AWS API and passed along to Terraform.

### It represents "ALL" at the API Level
AWS relies on standard IANA protocol numbers to filter traffic (e.g., TCP is 6, UDP is 17, ICMP is 1). Because protocol numbers are positive integers (from 0 to 255), AWS needed a way to signal the virtual firewall that it shouldn't look at a specific protocol number, but rather allow everything.

They chose -1 as a programmatic wildcard to represent "All Protocols". When you pass -1 to Terraform, it sends that exact integer straight to the AWS EC2 API.