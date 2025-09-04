# Troubleshooting Guide

This guide covers common issues you might encounter while deploying or using NovaBot, along with their solutions.

## 🚨 Deployment Issues

### Terraform Deployment Failures

#### Issue: "Access Denied" during Terraform apply
**Symptoms**: 
- Terraform fails with IAM access denied errors
- Cannot create resources in AWS

**Causes**:
- Insufficient AWS permissions
- Incorrect AWS credentials configuration
- Region-specific service limitations

**Solutions**:
1. **Verify AWS credentials**:
   ```bash
   aws sts get-caller-identity
   ```

2. **Check required permissions**:
   Your AWS user/role needs these permissions:
   - `AmazonBedrockFullAccess`
   - `IAMFullAccess` 
   - `AmazonS3FullAccess`
   - `AWSLambda_FullAccess`
   - `AmazonAPIGatewayAdministrator`
   - `SecretsManagerReadWrite`
   - `CloudWatchFullAccess`

3. **Use administrator access temporarily**:
   For initial setup, you may need `AdministratorAccess` policy

4. **Check service availability**:
   Ensure Bedrock is available in your chosen region

#### Issue: "Model not found" or "Model access denied"
**Symptoms**:
- Bedrock agent creation fails
- Model access errors in logs

**Solutions**:
1. **Request model access**:
   - Go to AWS Console → Bedrock → Model Access
   - Request access to required models:
     - `anthropic.claude-3-5-sonnet-20241022-v2:0`
     - `amazon.titan-embed-text-v1`

2. **Wait for approval**:
   - Most models are approved immediately
   - Some may require business justification

3. **Verify in correct region**:
   - Model access is region-specific
   - Ensure you're in the same region as your deployment

#### Issue: "OpenSearch Serverless collection creation failed"
**Symptoms**:
- Knowledge base creation fails
- OpenSearch collection errors

**Solutions**:
1. **Check service limits**:
   - OpenSearch Serverless has account limits
   - Request limit increases if needed

2. **Verify network configuration**:
   - Ensure proper VPC configuration if using custom networking
   - Check security group rules

3. **Check collection name conflicts**:
   - Collection names must be unique within region
   - Change the collection name in terraform.tfvars

### Lambda Function Issues

#### Issue: Lambda deployment fails with package size errors
**Symptoms**:
- Lambda function creation fails
- "Package too large" errors

**Solutions**:
1. **Check function size**:
   ```bash
   # Check packaged function size
   cd lambda/function_name
   npm install --production
   zip -r function.zip . -x "*.git*" "node_modules/.cache/*"
   ls -lh function.zip
   ```

2. **Optimize dependencies**:
   - Remove dev dependencies from production build
   - Use Lambda layers for shared dependencies
   - Consider using webpack for bundling

3. **Use S3 for large packages**:
   - Upload large packages to S3 first
   - Reference S3 location in Terraform

#### Issue: Lambda function timeout errors
**Symptoms**:
- Functions timing out after 30 seconds
- Incomplete responses from Bedrock

**Solutions**:
1. **Increase timeout**:
   ```hcl
   # In Lambda resource
   timeout = 300  # 5 minutes
   ```

2. **Optimize Bedrock calls**:
   - Use streaming where possible
   - Implement proper error handling
   - Add retry logic with exponential backoff

3. **Check Bedrock model performance**:
   - Some models are faster than others
   - Consider using different model variants

## 🌐 Widget Issues

### Widget Not Loading

#### Issue: Widget doesn't appear on website
**Symptoms**:
- No chat widget visible
- JavaScript errors in browser console

**Solutions**:
1. **Check script loading**:
   ```html
   <!-- Ensure script loads before initialization -->
   <script src="https://your-domain.com/novabot/widget.js"></script>
   <script>
   // Wait for script to load
   setTimeout(() => {
     NovaBot.init({
       apiUrl: 'https://your-api-gateway-url'
     });
   }, 100);
   </script>
   ```

2. **Verify CORS configuration**:
   - Check API Gateway CORS settings
   - Ensure your domain is in allowed origins

3. **Check browser console**:
   - Look for JavaScript errors
   - Verify network requests succeed

4. **Test with minimal configuration**:
   ```javascript
   NovaBot.init({
     apiUrl: 'https://your-api-gateway-url'
   });
   ```

#### Issue: Widget loads but doesn't connect
**Symptoms**:
- Widget appears but shows connection errors
- API calls fail with CORS or authentication errors

**Solutions**:
1. **Verify API Gateway URL**:
   ```bash
   # Test API endpoint directly
   curl -X POST https://your-api-gateway-url/chat \
        -H "Content-Type: application/json" \
        -d '{"message": "test"}'
   ```

2. **Check CORS headers**:
   ```bash
   # Test CORS preflight
   curl -X OPTIONS https://your-api-gateway-url/chat \
        -H "Origin: https://your-website.com" \
        -H "Access-Control-Request-Method: POST" \
        -v
   ```

3. **Verify SSL certificate**:
   - Ensure API Gateway has valid SSL certificate
   - Check for mixed content (HTTP/HTTPS) issues

### Message Sending Issues

#### Issue: Messages not sending or receiving
**Symptoms**:
- Send button doesn't work
- No responses from AI
- Error messages in widget

**Solutions**:
1. **Check Lambda function logs**:
   ```bash
   aws logs tail /aws/lambda/novabot-invoke-agent-dev --follow
   ```

2. **Verify Bedrock agent status**:
   ```bash
   aws bedrock-agent get-agent --agent-id YOUR_AGENT_ID
   ```

3. **Test agent directly**:
   ```bash
   aws bedrock-agent-runtime invoke-agent \
       --agent-id YOUR_AGENT_ID \
       --agent-alias-id TSTALIASID \
       --session-id test-session \
       --input-text "Hello" \
       output.json
   ```

## 🤖 AI Response Issues

### Knowledge Base Problems

#### Issue: AI doesn't use knowledge base content
**Symptoms**:
- Responses don't include information from uploaded documents
- Generic responses instead of specific knowledge

**Solutions**:
1. **Check knowledge base sync status**:
   ```bash
   aws bedrock-agent get-knowledge-base --knowledge-base-id YOUR_KB_ID
   ```

2. **Verify data source ingestion**:
   ```bash
   aws bedrock-agent list-data-source-ingestion-jobs \
       --knowledge-base-id YOUR_KB_ID \
       --data-source-id YOUR_DATA_SOURCE_ID
   ```

3. **Re-sync knowledge base**:
   ```bash
   aws bedrock-agent start-ingestion-job \
       --knowledge-base-id YOUR_KB_ID \
       --data-source-id YOUR_DATA_SOURCE_ID
   ```

4. **Check file formats**:
   - Ensure files are in supported formats (PDF, TXT, CSV, DOCX)
   - Verify file content is readable
   - Check file sizes (max 50MB per file)

#### Issue: Poor quality responses
**Symptoms**:
- Irrelevant or incorrect responses
- AI doesn't follow instructions properly

**Solutions**:
1. **Improve agent instructions**:
   ```hcl
   # In Bedrock agent configuration
   instruction = <<-EOT
   You are a helpful customer support assistant for NovaBot.
   Always be polite, professional, and helpful.
   Use the knowledge base to answer questions accurately.
   If you cannot find information, offer to create a support ticket.
   EOT
   ```

2. **Enhance knowledge base content**:
   - Add more comprehensive FAQs
   - Include detailed product information
   - Use clear, structured content format

3. **Test different prompts**:
   - Experiment with agent instructions
   - A/B test different response styles

### Zendesk Integration Issues

#### Issue: Tickets not created in Zendesk
**Symptoms**:
- Ticket creation requests fail
- Authentication errors with Zendesk API

**Solutions**:
1. **Verify Zendesk credentials**:
   ```bash
   # Check secret exists and is valid
   aws secretsmanager get-secret-value --secret-id "novabot/zendesk/credentials"
   ```

2. **Test Zendesk API directly**:
   ```bash
   curl -X POST "https://your-domain.zendesk.com/api/v2/tickets.json" \
        -H "Content-Type: application/json" \
        -u "your-email@company.com/token:your-api-token" \
        -d '{
          "ticket": {
            "subject": "Test ticket",
            "comment": {
              "body": "This is a test ticket"
            }
          }
        }'
   ```

3. **Check API token permissions**:
   - Ensure token has ticket creation permissions
   - Verify user has appropriate Zendesk role

4. **Update secret format**:
   ```json
   {
     "email": "agent@company.com",
     "token": "your-api-token",
     "domain": "your-company.zendesk.com"
   }
   ```

## 🔧 Performance Issues

### Slow Response Times

#### Issue: Long delays in AI responses
**Symptoms**:
- Responses take more than 10 seconds
- Timeout errors in widget

**Solutions**:
1. **Enable streaming responses**:
   ```javascript
   // In widget configuration
   NovaBot.init({
     apiUrl: 'https://your-api-gateway-url',
     streaming: true  // Enable real-time streaming
   });
   ```

2. **Optimize Lambda function**:
   ```javascript
   // Use connection pooling
   const bedrockClient = new BedrockAgentRuntimeClient({
     region: process.env.AWS_REGION,
     maxAttempts: 3,
     requestTimeout: 30000
   });
   ```

3. **Check Bedrock model performance**:
   - Monitor CloudWatch metrics
   - Consider using faster model variants
   - Optimize prompt length

### High Costs

#### Issue: Unexpected AWS charges
**Symptoms**:
- Higher than expected bills
- Rapid cost increase

**Solutions**:
1. **Monitor Bedrock usage**:
   ```bash
   # Check Bedrock costs in Cost Explorer
   # Set up billing alerts
   ```

2. **Optimize knowledge base queries**:
   - Reduce vector search dimensions if possible
   - Implement caching for common queries
   - Limit query frequency

3. **Set up cost alerts**:
   ```bash
   aws budgets create-budget \
       --account-id YOUR_ACCOUNT_ID \
       --budget '{
         "BudgetName": "NovaBot-Monthly",
         "BudgetLimit": {"Amount": "100", "Unit": "USD"},
         "TimeUnit": "MONTHLY",
         "BudgetType": "COST"
       }'
   ```

## 📊 Monitoring and Debugging

### CloudWatch Logs Analysis

#### Common Error Patterns

1. **"AccessDenied" errors**:
   - Check IAM permissions
   - Verify resource policies
   - Ensure cross-account access is configured

2. **"ThrottlingException" errors**:
   - Implement exponential backoff
   - Increase Lambda concurrency limits
   - Optimize request frequency

3. **"ValidationException" errors**:
   - Check request payload format
   - Verify required parameters
   - Validate against API schemas

#### Useful CloudWatch Queries

```sql
-- Find all errors in the last hour
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100

-- Monitor response times
fields @timestamp, @duration
| filter @message like /REPORT/
| stats avg(@duration) by bin(5m)

-- Count requests by status
fields @timestamp
| filter @message like /statusCode/
| stats count() by statusCode
```

### Testing Tools

#### API Testing Script
```bash
#!/bin/bash

API_URL="https://your-api-gateway-url"

# Test health endpoint
echo "Testing health endpoint..."
curl -X GET "$API_URL/health"

# Test chat endpoint
echo "Testing chat endpoint..."
curl -X POST "$API_URL/chat" \
     -H "Content-Type: application/json" \
     -d '{"message": "Hello, can you help me?"}'

# Test ticket creation
echo "Testing ticket creation..."
curl -X POST "$API_URL/chat" \
     -H "Content-Type: application/json" \
     -d '{"message": "I need help with my account. Please create a ticket."}'
```

## 🆘 Getting Additional Help

### Before Contacting Support

1. **Gather information**:
   - Error messages and stack traces
   - CloudWatch log entries
   - Configuration files (sanitized)
   - Steps to reproduce the issue

2. **Check documentation**:
   - AWS service documentation
   - Terraform provider documentation
   - NovaBot documentation

3. **Search existing issues**:
   - GitHub issues
   - AWS forums
   - Stack Overflow

### Contact Options

1. **GitHub Issues**: For bugs and feature requests
2. **GitHub Discussions**: For questions and community help
3. **AWS Support**: For AWS service-specific issues
4. **Zendesk Support**: For Zendesk integration issues

### Emergency Procedures

#### System Down Scenarios

1. **Immediate actions**:
   - Check AWS status page
   - Review recent deployments
   - Check CloudWatch alarms

2. **Rollback procedure**:
   ```bash
   # Rollback Terraform changes
   cd infra/terraform
   terraform apply -var-file=envs/dev/terraform.tfvars -target=module.previous_state
   ```

3. **Communication plan**:
   - Notify stakeholders
   - Update status page
   - Document incident timeline

Remember: Most issues can be resolved by checking CloudWatch logs and verifying configuration. When in doubt, start with the basics: permissions, connectivity, and data format validation.