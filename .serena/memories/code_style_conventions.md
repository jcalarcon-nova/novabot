# NovaBot Code Style & Conventions

## General Principles
- **KISS (Keep It Simple, Stupid)** - Choose straightforward solutions over complex ones
- **YAGNI (You Aren't Gonna Need It)** - Implement features only when needed
- **Dependency Inversion** - High-level modules depend on abstractions
- **Single Responsibility** - Each function/class has one clear purpose
- **Fail Fast** - Check for errors early and raise exceptions immediately

## File & Size Limits
- **Files**: Never exceed 500 lines of code
- **Functions**: Under 50 lines with single responsibility  
- **Classes**: Under 100 lines representing single concept
- **Line length**: Maximum 100 characters
- **Modular organization** by feature or responsibility

## Terraform Standards
- **Version pinning**: Use `>= 1.13.0, < 2.0` for Terraform, `~> 6.11` for AWS provider
- **Provider lock files**: Always commit `.terraform.lock.hcl`
- **S3 backend**: Use `use_lockfile = true`, DynamoDB locking deprecated
- **Module structure**: Separate modules for each AWS service/component
- **Environment separation**: Distinct state per env (dev/prod)

## TypeScript/JavaScript Standards
- **Type hints**: Always use TypeScript for Lambda functions
- **Error handling**: Implement proper try/catch with logging
- **Async/await**: Use modern async patterns
- **No hardcoded values**: Use environment variables and Secrets Manager
- **Structured logging**: Use JSON format with correlation IDs

## HCL (Terraform) Standards
- **Resource naming**: Use consistent snake_case
- **Variable validation**: Include descriptions and type constraints
- **Output values**: Provide meaningful outputs for module integration
- **Tags**: Use default_tags in provider configuration
- **Comments**: Document complex resource configurations

## Security Standards
- **Least privilege IAM**: Only grant necessary permissions
- **No secrets in code**: Use Secrets Manager and environment variables
- **Encryption**: Enable at rest and in transit
- **Input validation**: Validate all user inputs with proper schemas
- **Audit logging**: Enable CloudTrail and proper log retention

## Documentation Standards
- **README files**: Include setup, usage, and troubleshooting
- **Inline comments**: Explain complex business logic
- **API documentation**: Use OpenAPI specifications
- **Architecture diagrams**: Document system interactions
- **Runbook format**: Step-by-step operational procedures