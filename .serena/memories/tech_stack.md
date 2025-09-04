# NovaBot Tech Stack

## Infrastructure & DevOps
- **Terraform** v1.13.x - Infrastructure as Code
- **AWS Provider** v6.x - AWS resource management
- **GitHub Actions** - CI/CD pipeline
- **S3 Backend** with lockfile - Terraform state management

## AWS Services
- **Amazon Bedrock** - LLM agents and knowledge bases
- **AWS Lambda** - Serverless compute for business logic
- **API Gateway HTTP API** - REST API endpoints
- **Amazon S3** - Object storage and S3 Vectors (preview)
- **IAM** - Identity and access management
- **Secrets Manager** - Secure credential storage
- **CloudWatch Logs** - Logging and monitoring
- **Amazon Connect** - Future omni-channel support (scaffolded)

## Programming Languages & Runtimes
- **TypeScript/Node.js** - Lambda function implementation
- **HCL (HashiCorp Configuration Language)** - Terraform configuration
- **Vanilla JavaScript** - Web widget implementation
- **YAML** - OpenAPI schema definitions and CI/CD configs

## Development Tools
- **npm/Node.js** - Package management for Lambda functions
- **tfenv** - Terraform version management (recommended)
- **AWS CLI** - AWS service interaction
- **Git** - Version control

## Integration APIs
- **Zendesk Ticketing API** - Support ticket creation
- **Bedrock InvokeAgent API** - Real-time agent interaction
- **S3 Vectors API** - Knowledge base vector storage (preview)

## File Formats & Data
- **CSV files** - Knowledge base data sources
- **JSON** - API payloads and configuration
- **OpenAPI 3.0** - Action group schema definitions