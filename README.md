# aws-terraform-learning

A learning project: a Hello World Node.js server, containerized and pushed to
**Amazon ECR** by **GitHub Actions** (authenticating via **OIDC** — no static AWS
keys), with all AWS infrastructure defined in **Terraform (HCL)**.

## Layout

```
.
├── src/server.ts               # Hello World HTTP server (TypeScript)
├── Dockerfile                  # Multi-stage build → node:22-alpine, non-root
├── .dockerignore
├── .github/workflows/
│   └── build-and-push.yml      # CI: build image, push to ECR via OIDC
└── terraform/
    ├── ecr.tf                  # ECR repository + lifecycle policy
    ├── github-oidc.tf          # GitHub OIDC provider + IAM role/policy
    ├── ec2.tf                  # EC2 host, security group, instance IAM role
    ├── templates/              # user-data + deploy-app.sh (rendered by TF)
    ├── variables.tf            # region, repo, github owner/repo, ...
    ├── outputs.tf              # ecr_repository_url, ec2 outputs, ...
    └── ...
```

## Runtime architecture

```
push to main
    │
    ▼
GitHub Actions ──(OIDC)──▶ AWS
    ├─ build-and-push: build image → ECR
    └─ deploy: SSM Run Command ──▶ EC2 runs /usr/local/bin/deploy-app.sh
                                        └─ docker pull :latest + restart container
                                              exposed on http://<ec2-ip>:<host_port>
```

The EC2 host is reached via **SSM**, not SSH — no port 22, no SSH keys. The
instance's IAM role grants read-only ECR pull + SSM management.

## Run locally

```bash
npm install
npm run dev            # hot-reload server on http://localhost:3000
# or
npm run build && npm start
```

Endpoints: `/` → `Hello, World!`, `/health` → `{"status":"ok"}`.

## Build the container

```bash
docker build -t hello-world .
docker run -p 3000:3000 hello-world
```

## Deploy the AWS infrastructure

Requires AWS credentials with permissions to create ECR + IAM resources.

```bash
cd terraform
terraform init
terraform apply
```

This creates the ECR repository and a GitHub Actions IAM role. Note the outputs:

```bash
terraform output ecr_repository_url        # → ECR_REPOSITORY (GitHub var)
terraform output github_actions_role_arn   # → AWS_ROLE_ARN   (GitHub var)
```

> **If the account already has a GitHub OIDC provider** (only one is allowed per
> account), run with `-var="create_github_oidc_provider=false"` so Terraform
> reuses the existing one instead of trying to create a duplicate.

## Wire up GitHub Actions

The workflow reads three **repository variables** (Settings → Secrets and
variables → Actions → *Variables*). Set them with the values from above:

| Variable         | Value                                             |
| ---------------- | ------------------------------------------------- |
| `AWS_ROLE_ARN`    | `terraform output github_actions_role_arn`       |
| `ECR_REPOSITORY`  | repo **name** only, e.g. `hello-world`           |
| `AWS_REGION`      | your region, e.g. `eu-central-1`                 |
| `EC2_INSTANCE_ID` | `terraform output ec2_instance_id`               |

You can set them via the CLI:

```bash
gh variable set AWS_ROLE_ARN    --body "$(terraform -chdir=terraform output -raw github_actions_role_arn)"
gh variable set ECR_REPOSITORY  --body "$(terraform -chdir=terraform output -raw ecr_repository_url | cut -d/ -f2)"
gh variable set AWS_REGION      --body "eu-central-1"
gh variable set EC2_INSTANCE_ID --body "$(terraform -chdir=terraform output -raw ec2_instance_id)"
```

On every push to `main`, the workflow assumes the role via OIDC, **builds** the
image and pushes it to ECR (SHA + `latest`), then **deploys** by asking SSM to
re-run the deploy script on the instance. Find the live URL with:

```bash
terraform -chdir=terraform output app_url
```

> If Terraform ever **replaces** the instance, update the `EC2_INSTANCE_ID`
> variable with the new `terraform output ec2_instance_id`.

## Security notes

- CI uses **OIDC**, so no AWS access keys live in the repo or GitHub secrets.
- The IAM role trust policy is scoped to **this repo's `main` branch** by default
  (see `github_allowed_refs` in `variables.tf` to widen it).
- The ECR push policy is least-privilege, scoped to the one repository.
- The EC2 host has **no SSH exposed**; deploys go through SSM. Only `host_port`
  (default 80) is open to the internet — narrow `app_ingress_cidrs` to your IP
  for a private demo.
