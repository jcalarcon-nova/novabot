# NovaBot Task Completion Checklist

## When Code Changes Are Made

### Terraform Changes
1. **Format check**: Run `terraform fmt -check -recursive`
2. **Validation**: Run `terraform validate`  
3. **Plan review**: Run `terraform plan` and review changes
4. **Security scan**: Check for hardcoded secrets or overly permissive policies
5. **Documentation**: Update module README if interfaces changed

### Lambda Function Changes
1. **Build check**: Run `npm run build` for TypeScript functions
2. **Test suite**: Run `npm test` and ensure all tests pass
3. **Linting**: Run `eslint` or equivalent linter
4. **Package test**: Verify `zip -r function.zip dist/ node_modules/` works
5. **Environment variables**: Verify all required env vars are documented

### Web Widget Changes
1. **Browser testing**: Test in multiple browsers (Chrome, Firefox, Safari)
2. **Responsive design**: Test on mobile and desktop viewports
3. **JavaScript validation**: Run through JSLint or equivalent
4. **API integration**: Test against actual API endpoints
5. **Error handling**: Verify graceful degradation when APIs are down

## Before Committing Changes

### Code Quality Gates
1. **No hardcoded secrets**: Scan for API keys, passwords, or tokens
2. **Environment parity**: Ensure dev/prod configurations are consistent
3. **Error logging**: Verify proper error handling and logging
4. **Input validation**: Check all user inputs are validated
5. **Documentation**: Update relevant README files and inline comments

### Security Validation
1. **IAM permissions**: Review for least privilege compliance
2. **Network security**: Verify proper VPC and security group configs
3. **Encryption**: Ensure data is encrypted at rest and in transit
4. **Secrets rotation**: Document secret rotation procedures
5. **Compliance**: Check against AWS security best practices

## Deployment Validation

### Infrastructure Deployment
1. **Terraform apply**: Successfully deploy to development environment
2. **Resource verification**: Confirm all resources are created as expected
3. **Health checks**: Verify all endpoints return expected responses
4. **Integration testing**: Test complete user flow end-to-end
5. **Rollback plan**: Document rollback procedure if deployment fails

### Application Deployment
1. **Lambda deployment**: Verify functions deploy and execute correctly
2. **API Gateway**: Test all routes return proper responses
3. **Bedrock integration**: Confirm agent responds to test queries
4. **Knowledge base**: Verify RAG responses include relevant information
5. **Zendesk integration**: Test ticket creation with sample data

### Performance Validation  
1. **Load testing**: Test with expected user load
2. **Latency checks**: Verify response times meet SLA requirements
3. **Scaling verification**: Confirm auto-scaling works properly
4. **Cost monitoring**: Check AWS costs are within expected ranges
5. **Resource utilization**: Monitor Lambda memory and CPU usage

## Final Checklist

### Documentation Updates
- [ ] README files updated with new features or changes
- [ ] API documentation reflects current endpoints
- [ ] Architecture diagrams updated if structure changed
- [ ] Troubleshooting guides include new known issues
- [ ] Version numbers incremented appropriately

### Monitoring & Alerts
- [ ] CloudWatch dashboards show all relevant metrics
- [ ] Alerts configured for error rates and performance degradation
- [ ] Log retention policies are appropriate
- [ ] Cost anomaly detection is enabled
- [ ] Security monitoring is active

### Stakeholder Communication
- [ ] Product owner notified of completed features
- [ ] Operations team briefed on deployment changes
- [ ] Support team updated on new troubleshooting procedures
- [ ] End users notified of new capabilities (if applicable)
- [ ] Change log updated with release notes