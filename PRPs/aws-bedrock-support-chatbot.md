# PRP: AWS Bedrock Support Chatbot System with Terraform IaC

## Executive Summary
Build a complete end-to-end AWS Bedrock-powered support chatbot system with Terraform Infrastructure-as-Code, featuring Knowledge Base RAG, Zendesk ticket creation, and a web widget interface. This system will leverage Amazon Bedrock Agents with Actions, S3 Vectors for knowledge storage, and Lambda functions for integrations.

## Context & Requirements

### Core Components
1. **Terraform Infrastructure** (v1.13.x, AWS Provider v6.x)
   - S3 backend with lockfile (DynamoDB deprecated)
   - Modular architecture with environment separation
   - Provider lock files and version pinning

2. **AWS Services**
   - Bedrock Agents with OpenAPI-defined Actions
   - Knowledge Bases using S3 Vectors (preview)
   - Lambda functions (Zendesk, Lex fulfillment)
   - API Gateway HTTP API
   - Amazon Connect scaffolding (future-ready)
   - IAM, Secrets Manager, CloudWatch Logs

3. **Integrations**
   - Zendesk ticket creation via API
   - Web widget with streaming responses
   - CSV-based knowledge ingestion

### Documentation References
- Terraform S3 Backend: https://developer.hashicorp.com/terraform/language/backend/s3
- AWS Provider v6.x: https://github.com/hashicorp/terraform-provider-aws/releases
- Bedrock Agents API Schema: https://docs.aws.amazon.com/bedrock/latest/userguide/agents-api-schema.html
- Bedrock InvokeAgent: https://docs.aws.amazon.com/bedrock/latest/userguide/agents-invoke-agent.html
- Knowledge Base S3 Vectors: https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-vectors-getting-started.html
- Zendesk Tickets API: https://developer.zendesk.com/api-reference/ticketing/tickets/tickets/
- Terraform Provider Lock: https://developer.hashicorp.com/terraform/language/files/dependency-lock

## Implementation Blueprint

### Phase 1: Project Structure Setup

```
NovaBot/
├── infra/
│   ├── terraform/
│   │   ├── envs/
│   │   │   ├── dev/
│   │   │   │   ├── backend.hcl
│   │   │   │   ├── main.tf
│   │   │   │   ├── versions.tf
│   │   │   │   ├── variables.tf
│   │   │   │   └── outputs.tf
│   │   │   └── prod/
│   │   │       └── (same structure)
│   │   └── modules/
│   │       ├── bedrock_agent/
│   │       │   ├── main.tf
│   │       │   ├── variables.tf
│   │       │   ├── outputs.tf
│   │       │   └── openapi/
│   │       │       └── zendesk.yaml
│   │       ├── kb_s3_vectors/
│   │       ├── api_gateway_invoke_agent/
│   │       ├── lambda_zendesk_create_ticket/
│   │       ├── lambda_lex_fulfillment/
│   │       ├── connect_scaffold/
│   │       ├── iam/
│   │       └── observability/
├── lambda/
│   ├── zendesk_create_ticket/
│   │   ├── index.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   ├── lex_fulfillment/
│   │   └── (same structure)
│   └── invoke_agent/
│       └── (same structure)
├── web/
│   └── widget/
│       ├── widget.js
│       ├── widget.css
│       └── index.html
├── data/
│   └── knowledge_base/
│       ├── web_docs.csv
│       └── curated_articles.csv
├── .github/
│   └── workflows/
│       └── terraform.yml
├── Makefile
├── .gitignore
├── .terraform-version
└── README.md
```

### Phase 2: Terraform Foundation

#### versions.tf Template
```hcl
terraform {
  required_version = ">= 1.13.0, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.11"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "NovaBot"
      ManagedBy   = "Terraform"
    }
  }
}
```

#### backend.hcl Template (dev)
```hcl
bucket         = "nova-terraform-state"
key            = "novabot/dev/terraform.tfstate"
region         = "us-east-1"
use_lockfile   = true
encrypt        = true
```

### Phase 3: Bedrock Agent Module

#### OpenAPI Schema (zendesk.yaml)
```yaml
openapi: 3.0.1
info:
  title: Zendesk Support Ticket API
  version: "1.0.0"
  description: API for creating Zendesk support tickets
paths:
  /support/tickets:
    post:
      summary: Create a Zendesk support ticket
      operationId: createZendeskTicket
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [requester_email, subject, description]
              properties:
                requester_email:
                  type: string
                  format: email
                  description: Email of the ticket requester
                subject:
                  type: string
                  description: Ticket subject line
                description:
                  type: string
                  description: Detailed ticket description
                priority:
                  type: string
                  enum: [low, normal, high, urgent]
                  description: Ticket priority level
                tags:
                  type: array
                  items:
                    type: string
                  description: Tags for categorization
                plugin_version:
                  type: string
                  description: Plugin version information
                mule_runtime:
                  type: string
                  description: Mule runtime version
      responses:
        "200":
          description: Ticket created successfully
          content:
            application/json:
              schema:
                type: object
                properties:
                  ticket_id:
                    type: string
                  status:
                    type: string
```

### Phase 4: Lambda Functions

#### Zendesk Ticket Creation Lambda (TypeScript)
```typescript
// lambda/zendesk_create_ticket/index.ts
import { Handler } from 'aws-lambda';
import fetch from 'node-fetch';
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

const secretsClient = new SecretsManagerClient({ region: process.env.AWS_REGION });

interface BedrockActionEvent {
  body: string;
  httpMethod: string;
  apiPath: string;
  messageVersion: string;
}

interface TicketRequest {
  requester_email: string;
  subject: string;
  description: string;
  priority?: string;
  tags?: string[];
  plugin_version?: string;
  mule_runtime?: string;
}

async function getZendeskCredentials() {
  const command = new GetSecretValueCommand({
    SecretId: process.env.ZENDESK_SECRET_NAME
  });
  const response = await secretsClient.send(command);
  return JSON.parse(response.SecretString!);
}

export const handler: Handler = async (event: BedrockActionEvent) => {
  try {
    const ticketRequest: TicketRequest = JSON.parse(event.body);
    const credentials = await getZendeskCredentials();
    
    const authToken = Buffer.from(
      `${credentials.email}/token:${credentials.api_token}`
    ).toString('base64');
    
    const payload = {
      ticket: {
        requester: { email: ticketRequest.requester_email },
        subject: ticketRequest.subject,
        comment: { body: ticketRequest.description },
        priority: ticketRequest.priority || 'normal',
        tags: ticketRequest.tags || [],
        custom_fields: [
          { id: credentials.plugin_version_field_id, value: ticketRequest.plugin_version },
          { id: credentials.mule_runtime_field_id, value: ticketRequest.mule_runtime }
        ]
      }
    };
    
    const response = await fetch(
      `https://${credentials.subdomain}.zendesk.com/api/v2/tickets.json`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Basic ${authToken}`
        },
        body: JSON.stringify(payload)
      }
    );
    
    if (!response.ok) {
      throw new Error(`Zendesk API error: ${response.status}`);
    }
    
    const result = await response.json();
    
    return {
      statusCode: 200,
      body: JSON.stringify({
        ticket_id: result.ticket.id,
        status: 'created'
      })
    };
  } catch (error) {
    console.error('Error creating Zendesk ticket:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Failed to create ticket' })
    };
  }
};
```

### Phase 5: Web Widget

#### widget.js
```javascript
(function() {
  'use strict';
  
  const API_ENDPOINT = 'https://api.novabot.example.com/invoke-agent';
  let sessionId = null;
  
  class NovaBotWidget {
    constructor() {
      this.isOpen = false;
      this.messages = [];
      this.init();
    }
    
    init() {
      this.createWidget();
      this.attachEventListeners();
      this.startSession();
    }
    
    async startSession() {
      sessionId = 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    }
    
    async sendMessage(message) {
      this.addMessage('user', message);
      
      try {
        const response = await fetch(API_ENDPOINT, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            sessionId: sessionId,
            inputText: message,
            sessionAttributes: {}
          })
        });
        
        if (response.body) {
          const reader = response.body.getReader();
          const decoder = new TextDecoder();
          let buffer = '';
          
          while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            
            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split('\n');
            buffer = lines.pop() || '';
            
            for (const line of lines) {
              if (line.trim()) {
                try {
                  const data = JSON.parse(line);
                  if (data.chunk) {
                    this.appendToLastMessage('agent', data.chunk);
                  }
                  if (data.citations) {
                    this.addCitations(data.citations);
                  }
                } catch (e) {
                  console.error('Error parsing stream:', e);
                }
              }
            }
          }
        }
      } catch (error) {
        console.error('Error sending message:', error);
        this.addMessage('agent', 'Sorry, I encountered an error. Please try again.');
      }
    }
    
    createTicketButton() {
      const button = document.createElement('button');
      button.textContent = 'Create Support Ticket';
      button.onclick = () => {
        this.sendMessage('I need to create a support ticket');
      };
      return button;
    }
    
    // Additional widget methods...
  }
  
  // Initialize widget when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => new NovaBotWidget());
  } else {
    new NovaBotWidget();
  }
})();
```

### Phase 6: CI/CD Pipeline

#### GitHub Actions Workflow
```yaml
name: Terraform CI/CD

on:
  pull_request:
    paths:
      - 'infra/terraform/**'
  push:
    branches:
      - main
    paths:
      - 'infra/terraform/**'

env:
  TF_VERSION: 1.13.0
  AWS_REGION: us-east-1

jobs:
  terraform-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        working-directory: infra/terraform
      
      - name: Terraform Init
        run: terraform init -backend-config=envs/dev/backend.hcl
        working-directory: infra/terraform
      
      - name: Terraform Validate
        run: terraform validate
        working-directory: infra/terraform
      
      - name: Terraform Plan
        run: terraform plan -var-file=envs/dev/terraform.tfvars
        working-directory: infra/terraform
      
      - name: Terraform Apply (main branch only)
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve -var-file=envs/dev/terraform.tfvars
        working-directory: infra/terraform
```

## Implementation Tasks

### Task List (In Order)

1. **Project Setup**
   - [ ] Create directory structure
   - [ ] Initialize git repository
   - [ ] Setup .gitignore for Terraform, Node.js, Python
   - [ ] Create README.md with setup instructions

2. **Terraform Foundation**
   - [ ] Create versions.tf with provider requirements
   - [ ] Setup S3 backend configuration
   - [ ] Create variable definitions
   - [ ] Initialize Terraform and create lock file

3. **IAM and Security Module**
   - [ ] Create IAM roles for Lambda functions
   - [ ] Setup Bedrock agent execution role
   - [ ] Configure Secrets Manager for Zendesk credentials
   - [ ] Create KMS keys for encryption

4. **S3 and Knowledge Base Module**
   - [ ] Create S3 buckets for vector storage
   - [ ] Setup bucket policies and lifecycle rules
   - [ ] Implement Knowledge Base resource
   - [ ] Configure data source connections

5. **Lambda Functions**
   - [ ] Implement Zendesk ticket creation Lambda
   - [ ] Create Lex fulfillment Lambda
   - [ ] Build invoke-agent passthrough Lambda
   - [ ] Package and deploy Lambda functions

6. **Bedrock Agent Module**
   - [ ] Create Bedrock agent resource
   - [ ] Configure action groups with OpenAPI schema
   - [ ] Link Lambda functions to actions
   - [ ] Setup agent aliases and versions

7. **API Gateway Module**
   - [ ] Create HTTP API
   - [ ] Configure routes and integrations
   - [ ] Setup CORS policies
   - [ ] Enable request/response logging

8. **Web Widget**
   - [ ] Implement chat widget JavaScript
   - [ ] Create CSS styling
   - [ ] Build demo HTML page
   - [ ] Test streaming responses

9. **Amazon Connect Scaffold** (Optional/Future)
   - [ ] Create Connect instance
   - [ ] Setup contact flows
   - [ ] Configure Lex bot association
   - [ ] Wire Lambda permissions

10. **CI/CD Pipeline**
    - [ ] Setup GitHub Actions workflow
    - [ ] Configure OIDC authentication
    - [ ] Implement Terraform checks
    - [ ] Add automated testing

11. **Documentation and Examples**
    - [ ] Create deployment guide
    - [ ] Add environment setup instructions
    - [ ] Document API endpoints
    - [ ] Provide usage examples

## Validation Gates

### Infrastructure Validation
```bash
# Terraform validation
cd infra/terraform
terraform fmt -check -recursive
terraform init -backend-config=envs/dev/backend.hcl
terraform validate
terraform plan -var-file=envs/dev/terraform.tfvars

# Verify state locking
terraform state list
```

### Lambda Function Testing
```bash
# TypeScript Lambda compilation
cd lambda/zendesk_create_ticket
npm install
npm run build
npm test

# Package for deployment
zip -r function.zip dist/ node_modules/
```

### Integration Testing
```bash
# Test Bedrock agent invocation
aws bedrock-agent-runtime invoke-agent \
  --agent-id <AGENT_ID> \
  --agent-alias-id <ALIAS_ID> \
  --session-id test-session \
  --input-text "I need help with my Mule application"

# Test Zendesk ticket creation
curl -X POST https://api.novabot.example.com/support/tickets \
  -H "Content-Type: application/json" \
  -d '{
    "requester_email": "test@example.com",
    "subject": "Test Ticket",
    "description": "This is a test ticket"
  }'
```

### Security Validation
```bash
# Check IAM policies
aws iam simulate-principal-policy \
  --policy-source-arn <LAMBDA_ROLE_ARN> \
  --action-names bedrock:InvokeAgent \
  --resource-arns <AGENT_ARN>

# Verify secrets
aws secretsmanager get-secret-value \
  --secret-id zendesk-credentials \
  --query SecretString
```

## Error Handling Considerations

1. **Terraform State**
   - Always use remote state with locking
   - Backup state files before major changes
   - Use workspace for environment separation

2. **Lambda Errors**
   - Implement retry logic with exponential backoff
   - Use dead letter queues for failed invocations
   - Log all errors to CloudWatch

3. **Zendesk API**
   - Handle rate limiting (429 responses)
   - Implement idempotency with external_id
   - Validate ticket data before submission

4. **Bedrock Agent**
   - Handle streaming interruptions
   - Implement session timeout handling
   - Provide fallback responses for errors

## Security Best Practices

1. **Secrets Management**
   - Never hardcode credentials
   - Use AWS Secrets Manager for all sensitive data
   - Rotate API tokens regularly

2. **IAM Policies**
   - Follow least privilege principle
   - Use service-specific roles
   - Enable MFA for production deployments

3. **Network Security**
   - Use VPC endpoints where possible
   - Implement WAF rules for API Gateway
   - Enable CloudTrail logging

4. **Data Protection**
   - Encrypt data at rest and in transit
   - Implement PII detection and masking
   - Regular security audits

## Performance Optimization

1. **Lambda Functions**
   - Use provisioned concurrency for consistent performance
   - Optimize cold start times
   - Implement connection pooling

2. **Knowledge Base**
   - Optimize chunk sizes for better retrieval
   - Regular reindexing of vectors
   - Monitor query performance

3. **API Gateway**
   - Enable caching where appropriate
   - Use CloudFront for global distribution
   - Implement rate limiting

## Monitoring and Observability

1. **CloudWatch Dashboards**
   - Lambda invocation metrics
   - API Gateway request/response times
   - Bedrock agent usage statistics

2. **Alarms**
   - High error rates
   - Throttling events
   - Cost anomalies

3. **Logging**
   - Structured logging in JSON format
   - Correlation IDs for request tracing
   - Log retention policies

## Cost Optimization

1. **Resource Sizing**
   - Right-size Lambda memory allocations
   - Use Spot instances for non-critical workloads
   - Implement auto-scaling policies

2. **Storage**
   - S3 lifecycle policies for old data
   - Intelligent tiering for knowledge base
   - Regular cleanup of unused resources

## Success Criteria

- [ ] Terraform applies successfully without errors
- [ ] All Lambda functions deploy and execute correctly
- [ ] Bedrock agent responds to queries with relevant information
- [ ] Zendesk tickets are created with proper formatting
- [ ] Web widget displays and streams responses smoothly
- [ ] CI/CD pipeline runs all checks successfully
- [ ] Security scan shows no critical vulnerabilities
- [ ] Performance metrics meet SLA requirements

## Confidence Score: 9/10

This PRP provides comprehensive context and implementation details for building the AWS Bedrock Support Chatbot system. The score is 9/10 because:

**Strengths:**
- Complete project structure and architecture
- Detailed code examples for all components
- Extensive documentation references
- Clear validation gates and testing procedures
- Security and performance considerations

**Minor Gap:**
- Some AWS service configurations may need adjustment based on specific AWS account settings and regional availability of S3 Vectors (preview feature)

The implementation should succeed in one pass with this comprehensive blueprint and all necessary context provided.