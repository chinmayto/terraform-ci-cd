---
title: Deploy a Serverless Website with Terraform, Jenkins & Nexus
published: false
description: Step-by-step guide to building, deploying and destroying a serverless website (API Gateway + Lambda) across dev, staging and production using Terraform pipelines in Jenkins.
tags: terraform, jenkins, aws, devops
cover_image:
---

# Deploy a Serverless Website with Terraform, Jenkins & Nexus

This repo provisions a simple serverless website on AWS using **API Gateway v2 + Lambda**, managed by Terraform. A Jenkins pipeline handles the full lifecycle — build, deploy, and destroy — across three environments, and uploads artifacts to Nexus.

---

## Architecture

```
Browser → API Gateway (HTTP) → Lambda → HTML response
```

- Lambda serves a static HTML page with an environment badge
- API Gateway v2 routes `GET /` to the Lambda function
- Terraform state is stored remotely in S3 with DynamoDB locking
- Build artifacts (source + plan file) are zipped and pushed to Nexus

---

## Prerequisites

Before running any pipeline, make sure you have:

- Jenkins with these plugins installed:
  - [Pipeline](https://plugins.jenkins.io/workflow-aggregator/)
  - [AWS Credentials](https://plugins.jenkins.io/aws-credentials/)
  - [Credentials Binding](https://plugins.jenkins.io/credentials-binding/)
- Terraform >= 1.3.0 installed on the Jenkins agent
- An S3 bucket and DynamoDB table for Terraform remote state
- A Nexus instance with repositories for each environment
- Two Jenkins credentials configured:

| Credential ID      | Type                  | Description                        |
|--------------------|-----------------------|------------------------------------|
| `aws-credentials`  | AWS Access Key        | IAM key with Lambda, API GW access |
| `nexus-credentials`| Username with password| Nexus login                        |

---

## Repository Structure

```
├── main.tf                        # Root module, provider & backend config
├── variables.tf                   # Input variable declarations
├── outputs.tf                     # Stack outputs (website URL, etc.)
├── backend.hcl.example            # S3 backend config template
├── environments/
│   ├── dev.tfvars                 # Dev environment values
│   ├── staging.tfvars             # Staging environment values
│   └── production.tfvars          # Production environment values
├── modules/
│   ├── lambda/                    # Lambda function + IAM + CloudWatch
│   │   └── src/index.js           # HTML handler
│   └── api_gateway/               # HTTP API Gateway + routes + permissions
└── Jenkinsfile                    # Pipeline definition
```

---

## Step 1 — Configure the Backend

Copy the example backend config and fill in your S3 bucket details:

```bash
cp backend.hcl.example backend.hcl
```

Edit `backend.hcl`:

```hcl
bucket         = "your-terraform-state-bucket"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
```

> `backend.hcl` is gitignored — never commit it.

---

## Step 2 — Update the tfvars Files

Each environment has its own tfvars file under `environments/`. Update the Nexus values to match your setup:

```hcl
# environments/dev.tfvars
environment        = "dev"
aws_region         = "us-east-1"
lambda_memory_size = 128
lambda_timeout     = 10
log_retention_days = 3
nexus_url          = "https://nexus.your-domain.com"
nexus_repo         = "terraform-artifacts-dev"
```

Repeat for `staging.tfvars` and `production.tfvars`.

---

## Step 3 — Create the Jenkins Pipeline Job

1. In Jenkins, click **New Item**
2. Enter a name (e.g. `terraform-website`) and select **Pipeline**
3. Under **Pipeline**, set **Definition** to `Pipeline script from SCM`
4. Set **SCM** to Git and point it at this repository
5. Set **Script Path** to `Jenkinsfile`
6. Save the job

---

## Step 4 — Running the Pipeline

Every run asks for two parameters:

| Parameter    | Options                        | Description                        |
|--------------|--------------------------------|------------------------------------|
| `ENVIRONMENT`| `dev` / `staging` / `production` | Which tfvars file to use         |
| `TF_ACTION`  | `plan` / `apply` / `destroy`   | What Terraform should do           |

### Build (Plan only)

Use this to preview changes without touching any infrastructure.

1. Click **Build with Parameters**
2. Set `ENVIRONMENT` → `dev` (or your target)
3. Set `TF_ACTION` → `plan`
4. Click **Build**

The pipeline will run `terraform init`, `validate`, and `plan`, then zip the artifacts and upload them to Nexus. No infrastructure is created.

---

### Deploy (Apply)

Use this to actually create or update infrastructure.

1. Click **Build with Parameters**
2. Set `ENVIRONMENT` → `dev`, `staging`, or `production`
3. Set `TF_ACTION` → `apply`
4. Click **Build**
5. The pipeline will pause at the **Terraform Apply** stage and ask:

```
Apply changes to <environment>?
[ Yes, apply ]
```

6. Click **Yes, apply** to proceed

> For `production`, double-check the plan output in the console logs before approving.

After a successful apply, the website URL is printed in the Terraform outputs:

```
Outputs:
website_url = "https://<api-id>.execute-api.us-east-1.amazonaws.com"
```

---

### Destroy

Use this to tear down all infrastructure for an environment.

1. Click **Build with Parameters**
2. Set `ENVIRONMENT` → target environment
3. Set `TF_ACTION` → `destroy`
4. Click **Build**
5. The pipeline will pause and ask:

```
DESTROY <environment> environment?
[ Yes, destroy ]
```

6. Click **Yes, destroy** to confirm

> This is irreversible. All Lambda functions, API Gateway resources, IAM roles and CloudWatch log groups for that environment will be deleted.

---

## Pipeline Stages

```
Checkout → Init → Validate → Plan → Package & Upload to Nexus → Apply/Destroy (if selected)
```

| Stage              | What it does                                                  |
|--------------------|---------------------------------------------------------------|
| Checkout           | Pulls the latest code from SCM                                |
| Terraform Init     | Initialises providers and configures the S3 backend           |
| Terraform Validate | Checks HCL syntax and module references                       |
| Terraform Plan     | Generates an execution plan saved as `tfplan-<env>`           |
| Package Artifacts  | Zips TF source + plan file, archives in Jenkins               |
| Upload to Nexus    | Pushes the zip to the Nexus repo defined in the tfvars file   |
| Terraform Apply    | Applies the saved plan (requires manual approval)             |
| Terraform Destroy  | Destroys all resources (requires manual approval)             |

---

## Nexus Artifact Layout

Artifacts are uploaded to:

```
<nexus_url>/repository/<nexus_repo>/<environment>/terraform-<environment>-<build_number>.zip
```

Example:

```
https://nexus.your-domain.com/repository/terraform-artifacts-dev/dev/terraform-dev-42.zip
```

---

## Environment Differences

| Setting            | dev   | staging | production |
|--------------------|-------|---------|------------|
| Lambda memory (MB) | 128   | 256     | 512        |
| Lambda timeout (s) | 10    | 15      | 30         |
| Log retention (days)| 3   | 7       | 30         |

---

## Troubleshooting

**`Error: No valid credential sources found`**
→ Check that the `aws-credentials` Jenkins credential ID matches exactly and the IAM user has the required permissions.

**`curl: (22) The requested URL returned error: 401`**
→ The `nexus-credentials` username or password is wrong. Verify in Jenkins → Manage Credentials.

**`Error acquiring the state lock`**
→ A previous run may have crashed mid-apply. Manually release the lock in DynamoDB or run `terraform force-unlock <lock-id>` on the Jenkins agent.

**Plan succeeds but Apply stage never appears**
→ Make sure `TF_ACTION` is set to `apply`, not `plan`.

---

## License

MIT
