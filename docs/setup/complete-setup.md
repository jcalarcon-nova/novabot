# Complete Setup Guide

This comprehensive guide will walk you through setting up NovaBot from start to finish, including all prerequisites, deployment steps, and configuration.

## 📋 Prerequisites Checklist

Before starting the setup process, ensure you have:

### Required Accounts and Access
- [ ] AWS Account with billing enabled
- [ ] AWS CLI configured with appropriate permissions
- [ ] Zendesk account (any tier)
- [ ] GitHub account (for CI/CD pipeline)

### Required Software
- [ ] Terraform v1.13.x or later
- [ ] AWS CLI v2.x
- [ ] Node.js v18.x or later
- [ ] npm or yarn
- [ ] Git

### AWS Permissions Required
Your AWS user/role needs the following permissions:
- [ ] Full access to AWS Bedrock
- [ ] IAM role creation and management
- [ ] S3 bucket creation and management
- [ ] Lambda function deployment
- [ ] API Gateway management
- [ ] Secrets Manager access
- [ ] CloudWatch and CloudTrail access
- [ ] OpenSearch Serverless access

## 🏗️ Architecture Overview

Before diving into setup, let's understand what we're building:

1. **Knowledge Base**: S3 bucket with OpenSearch Serverless for vector storage
2. **Bedrock Agent**: AI agent with access to knowledge base and custom actions
3. **Lambda Functions**: TypeScript functions for Zendesk integration and agent invocation
4. **API Gateway**: HTTP API for web widget communication
5. **Web Widget**: JavaScript chat interface for websites
6. **CI/CD Pipeline**: GitHub Actions for automated deployment

## 🚀 Step-by-Step Setup

### Step 1: Environment Preparation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-org/NovaBot.git
   cd NovaBot
   ```

2. **Verify prerequisites**:
   ```bash
   # Check Terraform version
   terraform version

   # Check AWS CLI version and configuration
   aws --version
   aws sts get-caller-identity

   # Check Node.js version
   node --version
   npm --version
   ```

3. **Request AWS Bedrock model access**:
   - Navigate to AWS Console → Bedrock → Model Access
   - Request access to:
     - `anthropic.claude-3-5-sonnet-20241022-v2:0`
     - `amazon.titan-embed-text-v1`
   - Wait for approval (usually immediate for standard models)

### Step 2: Zendesk Configuration

1. **Create Zendesk API token**:
   - Log into your Zendesk admin panel
   - Navigate to Admin → Channels → API
   - Enable token access
   - Create a new token and save it securely

2. **Note your Zendesk details**:
   - Subdomain: `your-company.zendesk.com`
   - Agent email: The email address of the user creating tickets
   - API token: Generated in step 1

### Step 3: AWS Secrets Manager Setup

Store your Zendesk credentials securely:

```bash
# Create the Zendesk credentials secret
aws secretsmanager create-secret \
    --name "novabot/zendesk/credentials" \
    --description "Zendesk API credentials for NovaBot" \
    --secret-string '{
        "email": "your-agent@company.com",
        "token": "your-api-token",
        "domain": "your-company.zendesk.com"
    }'
```

### Step 4: Domain Configuration (Optional but Recommended)

Before configuring Terraform, decide on your domain strategy:

#### Option A: Use Default API Gateway URL (Simplest)
Skip to Step 5 if you don't need custom domains.

#### Option B: Use Custom Domain with Existing Certificate
If you have an existing SSL certificate:

1. **Get certificate ARN**:
   ```bash
   aws acm list-certificates --region us-east-1
   ```

2. **Get hosted zone ID**:
   ```bash
   aws route53 list-hosted-zones --query "HostedZones[?Name=='nova-aicoe.com.'].Id" --output text
   ```

#### Option C: Auto-create Everything (Recommended)
Let NovaBot create the SSL certificate and manage DNS automatically.

### Step 5: Terraform Configuration

1. **Navigate to Terraform environment directory**:
   ```bash
   cd infra/terraform/envs/dev
   ```

2. **Copy configuration template**:
   ```bash
   # Copy the example file
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Configure environment variables**:
   Edit `terraform.tfvars` with your specific values:

   **Basic Configuration (No Custom Domain)**:
   ```hcl
   # Core Configuration
   project_name = "novabot"
   environment = "dev"
   aws_region = "us-east-1"

   # Zendesk Configuration
   zendesk_subdomain = "your-company"  # From your-company.zendesk.com

   # Bedrock Configuration
   bedrock_agent_model = "anthropic.claude-3-sonnet-20240229-v1:0"

   # S3 Configuration (auto-generated if empty)
   knowledge_base_s3_bucket = ""

   # Domain Configuration (disabled)
   enable_custom_domain = false

   # Tags
   tags = {
     Environment = "development"
     Project     = "NovaBot"
     ManagedBy   = "Terraform"
     Owner       = "your-team"
   }
   ```

   **Advanced Configuration (With Custom Domain)**:
   ```hcl
   # Core Configuration
   project_name = "novabot"
   environment = "dev" 
   aws_region = "us-east-1"

   # Zendesk Configuration
   zendesk_subdomain = "your-company"

   # Bedrock Configuration
   bedrock_agent_model = "anthropic.claude-3-sonnet-20240229-v1:0"

   # S3 Configuration
   knowledge_base_s3_bucket = ""

   # Domain Configuration (enabled with auto SSL)
   api_domain_name = "api-novabot.dev.nova-aicoe.com"
   root_domain_name = "nova-aicoe.com"
   enable_custom_domain = true
   create_certificate = true
   create_hosted_zone = false  # Use existing zone
   existing_hosted_zone_id = "Z1234567890ABC"  # Your Route 53 zone ID

   # Tags
   tags = {
     Environment = "development"
     Project     = "NovaBot"
     ManagedBy   = "Terraform"
     Owner       = "your-team"
   }
   ```

4. **Verify Route 53 setup** (if using custom domains):
   ```bash
   # Check if hosted zone exists
   aws route53 get-hosted-zone --id Z1234567890ABC

   # Verify domain ownership
   dig NS nova-aicoe.com
   ```

### Step 6: Infrastructure Deployment

1. **Initialize Terraform**:
   ```bash
   # You should already be in infra/terraform/envs/dev
   terraform init
   ```

2. **Plan the deployment**:
   ```bash
   terraform plan -var-file=terraform.tfvars
   ```

   Review the planned changes carefully. With custom domains enabled, you should see:
   - Route 53 hosted zone (if creating new)
   - ACM certificate with validation records
   - API Gateway custom domain configuration
   - DNS A-record for the API domain

3. **Apply the infrastructure**:
   ```bash
   terraform apply -var-file=terraform.tfvars
   ```

   **Deployment Timeline**:
   - **Basic resources** (5-10 minutes): IAM, S3, Lambda functions
   - **Bedrock components** (3-5 minutes): Knowledge Base, Agent
   - **SSL Certificate validation** (5-30 minutes): DNS validation
   - **Total time**: 15-45 minutes (depending on certificate validation)

   The deployment creates:
   - IAM roles and policies
   - S3 bucket for knowledge base
   - OpenSearch Serverless collection
   - Bedrock Knowledge Base
   - Lambda functions (3 functions)
   - Bedrock Agent with actions
   - API Gateway v2 with custom domain (if enabled)
   - Route 53 DNS records (if custom domain enabled)
   - ACM SSL certificate (if create_certificate = true)

4. **Monitor deployment progress**:
   ```bash
   # Watch certificate validation (if creating certificate)
   aws acm describe-certificate --certificate-arn $(terraform output -raw certificate_arn) --query 'Certificate.Status'

   # Check DNS propagation
   dig api-novabot.dev.nova-aicoe.com
   ```

5. **Save important outputs**:
   ```bash
   # Get API Gateway URLs
   terraform output api_gateway_url
   terraform output api_gateway_custom_domain_url  # If custom domain enabled

   # Get S3 bucket name
   terraform output knowledge_base_bucket_name

   # Get Bedrock Agent ID
   terraform output bedrock_agent_id

   # Get certificate ARN (if created)
   terraform output certificate_arn

   # Get hosted zone details
   terraform output hosted_zone_id
   terraform output name_servers
   ```

6. **Verify SSL certificate** (if using custom domain):
   ```bash
   # Test SSL certificate
   curl -I https://api-novabot.dev.nova-aicoe.com/health

   # Check certificate details
   openssl s_client -connect api-novabot.dev.nova-aicoe.com:443 -servername api-novabot.dev.nova-aicoe.com < /dev/null 2>/dev/null | openssl x509 -text -noout
   ```

### Step 7: Knowledge Base Population

1. **Upload sample data**:
   ```bash
   # Navigate back to project root
   cd ../../

   # Upload CSV files to knowledge base bucket
   aws s3 cp data/knowledge_base/ s3://$(terraform -chdir=infra/terraform output -raw knowledge_base_bucket_name)/ --recursive
   ```

2. **Verify upload**:
   ```bash
   # List files in the bucket
   aws s3 ls s3://$(terraform -chdir=infra/terraform output -raw knowledge_base_bucket_name)/
   ```

3. **Trigger knowledge base sync**:
   The knowledge base will automatically index the uploaded files. This process can take 5-15 minutes.

### Step 8: Lambda Function Deployment

The Lambda functions are deployed automatically by Terraform, but you can verify they're working:

1. **Test invoke-agent Lambda**:
   ```bash
   aws lambda invoke \
       --function-name novabot-invoke-agent-dev \
       --payload '{"body": "{\"message\": \"Hello, can you help me?\"}", "headers": {}}' \
       response.json

   cat response.json
   ```

2. **Test Zendesk Lambda**:
   ```bash
   aws lambda invoke \
       --function-name novabot-zendesk-create-ticket-dev \
       --payload '{"body": "{\"subject\": \"Test Ticket\", \"description\": \"This is a test ticket\", \"priority\": \"normal\"}", "headers": {}}' \
       response.json

   cat response.json
   ```

### Step 9: Web Widget Deployment

1. **Get the API URL**:
   ```bash
   # Get the appropriate API URL based on your configuration
   
   # If using custom domain:
   API_URL=$(terraform output -raw api_gateway_custom_domain_url)
   echo "Custom Domain API URL: $API_URL"
   
   # If using default API Gateway URL:
   API_URL=$(terraform output -raw api_gateway_url)
   echo "Default API Gateway URL: $API_URL"
   ```

2. **Configure widget**:
   Edit `web/widget/widget.js` to update the API URL:
   ```javascript
   // Update this line with your API Gateway URL
   const API_BASE_URL = 'https://api-novabot.dev.nova-aicoe.com';  // Or your custom domain
   ```

3. **Deploy widget files**:
   ```bash
   # Navigate back to project root if you're still in terraform directory
   cd ../../../

   # Copy widget files to your web server or CDN
   cp web/widget/* /path/to/your/webserver/novabot/

   # Or upload to S3 for CDN distribution
   aws s3 cp web/widget/ s3://your-cdn-bucket/novabot/ --recursive
   
   # Or serve directly from the project for testing
   python3 -m http.server 8080 --directory web/widget
   ```

4. **Add widget to your website**:
   ```html
   <!DOCTYPE html>
   <html>
   <head>
       <title>Your Website</title>
   </head>
   <body>
       <!-- Your website content -->
       
       <!-- NovaBot Widget (before closing body tag) -->
       <script src="https://your-domain.com/novabot/widget.js"></script>
       <script>
       NovaBot.init({
           // Use your deployed API URL (custom domain or default)
           apiUrl: 'https://api-novabot.dev.nova-aicoe.com',
           theme: 'light',
           position: 'bottom-right',
           title: 'Need Help?',
           subtitle: 'Chat with our AI assistant'
       });
       </script>
   </body>
   </html>
   ```

5. **Test widget locally** (optional):
   ```html
   <!-- For local testing with custom domains -->
   <!DOCTYPE html>
   <html>
   <head>
       <title>NovaBot Test Page</title>
   </head>
   <body>
       <h1>NovaBot Widget Test</h1>
       <p>The chat widget should appear in the bottom right corner.</p>
       
       <script src="widget.js"></script>
       <script>
       NovaBot.init({
           apiUrl: 'https://api-novabot.dev.nova-aicoe.com',
           theme: 'light',
           position: 'bottom-right',
           title: 'Test Assistant',
           subtitle: 'Testing the NovaBot widget'
       });
       </script>
   </body>
   </html>
   ```

### Step 10: Testing and Validation

1. **Test the complete flow**:
   - Open your website with the widget
   - Send a message through the widget
   - Verify the AI responds appropriately
   - Test ticket creation functionality

2. **Monitor CloudWatch logs**:
   ```bash
   # View invoke-agent logs
   aws logs tail /aws/lambda/novabot-invoke-agent-dev --follow

   # View Zendesk logs
   aws logs tail /aws/lambda/novabot-zendesk-create-ticket-dev --follow
   ```

3. **Verify Bedrock Agent**:
   ```bash
   # Test agent directly
   aws bedrock-agent-runtime invoke-agent \
       --agent-id $(terraform -chdir=infra/terraform output -raw bedrock_agent_id) \
       --agent-alias-id TSTALIASID \
       --session-id "test-session-$(date +%s)" \
       --input-text "Can you help me reset my password?" \
       output.json

   cat output.json
   ```

### Step 11: GitHub Actions Setup (Optional)

1. **Configure GitHub secrets**:
   In your GitHub repository settings, add these secrets:
   - `AWS_ROLE_ARN`: IAM role ARN for GitHub Actions
   - `SLACK_WEBHOOK_URL`: For deployment notifications (optional)

2. **Enable OIDC provider in AWS**:
   ```bash
   # This is done automatically by Terraform if you enable it
   # Set enable_github_oidc = true in terraform.tfvars
   ```

3. **Test CI/CD pipeline**:
   - Make a change to Terraform code
   - Create a pull request
   - Verify the pipeline runs plan and validation
   - Merge to main to trigger deployment

## 🔍 Post-Deployment Verification

### Checklist
- [ ] All Lambda functions deployed successfully
- [ ] Bedrock Agent created and active
- [ ] Knowledge Base populated and indexed
- [ ] API Gateway accessible
- [ ] Web widget loads and connects
- [ ] End-to-end conversation works
- [ ] Zendesk ticket creation works
- [ ] Monitoring and logging configured

### Common Issues and Solutions

**Issue**: Bedrock Agent not responding
- **Solution**: Check model access permissions and agent status

**Issue**: Widget not loading
- **Solution**: Verify CORS settings in API Gateway

**Issue**: Knowledge Base empty
- **Solution**: Check S3 bucket permissions and file formats

**Issue**: Zendesk integration failing
- **Solution**: Verify API credentials in Secrets Manager

## 📊 Monitoring and Maintenance

### Regular Tasks
1. **Monitor AWS costs** - Set up billing alerts
2. **Review CloudWatch logs** - Check for errors or performance issues
3. **Update knowledge base** - Keep support content current
4. **Security updates** - Keep Lambda dependencies updated
5. **Performance optimization** - Monitor response times and optimize as needed

### Scaling Considerations
- **Lambda concurrency limits** - Increase if needed for high volume
- **API Gateway throttling** - Adjust limits based on usage
- **Knowledge Base size** - Monitor storage and query performance
- **Cost optimization** - Review and optimize AWS service usage

## 🎯 Next Steps

After successful deployment:

1. **Customize the AI responses** - Train with your specific data
2. **Enhance the web widget** - Customize appearance and features
3. **Set up monitoring dashboards** - Create CloudWatch dashboards
4. **Implement analytics** - Track usage and performance metrics
5. **Plan for production** - Consider multi-region deployment

## 🆘 Getting Help

If you encounter issues during setup:

1. **Check the troubleshooting guide** - [Troubleshooting](../troubleshooting/common-issues.md)
2. **Review CloudWatch logs** - Look for specific error messages
3. **Consult AWS documentation** - For service-specific issues
4. **Open a GitHub issue** - For bugs or feature requests
5. **Join community discussions** - For questions and tips

Remember: The setup process should take 30-45 minutes for a standard deployment, not including AWS service provisioning time.