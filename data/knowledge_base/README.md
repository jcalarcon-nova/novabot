# NovaBot Knowledge Base

This directory contains the knowledge base files for the NovaBot AI support system. The knowledge base is used by Amazon Bedrock Knowledge Bases for Retrieval Augmented Generation (RAG) to provide accurate and contextual responses.

## Structure

The knowledge base consists of multiple CSV files, each containing structured Q&A data for different categories:

### Existing Knowledge Base Files

- **`company_info.csv`** - General company information and policies
- **`error_codes.csv`** - Error codes and their explanations  
- **`faq.csv`** - Frequently asked questions
- **`product_info.csv`** - Product specifications and information
- **`support_policies.csv`** - Support procedures and policies
- **`troubleshooting.csv`** - General troubleshooting guides

### New Knowledge Base Files

- **`datadog_mulesoft_integration.csv`** - ✨ **NEW**: Comprehensive Datadog MuleSoft Integration support knowledge base (270 entries)

## File Format

Each CSV file follows the same standardized format:

```csv
question,answer,category,tags,priority
"Question text","Detailed answer with context","category_name","tag1,tag2,tag3","high|medium|low"
```

### Field Descriptions

- **`question`**: The question or issue description
- **`answer`**: Comprehensive answer with step-by-step instructions
- **`category`**: Categorization for better organization (e.g., "datadog-mulesoft", "billing", "support")
- **`tags`**: Comma-separated tags for better searchability (e.g., "integration,configuration,activation")
- **`priority`**: Priority level (high, medium, low) based on urgency and impact

## Datadog MuleSoft Integration Knowledge Base

### Overview

The new `datadog_mulesoft_integration.csv` contains 270 carefully curated support articles covering:

- **Activation & Configuration**: Setup procedures and initial configuration
- **Integration Issues**: Common integration problems and solutions
- **Troubleshooting**: Diagnostic steps and error resolution
- **Performance Optimization**: Best practices for optimal performance
- **Authentication & Security**: Credential management and security considerations
- **Deployment Scenarios**: Different deployment patterns and requirements

### Statistics

- **Total Entries**: 270 support articles
- **Priority Distribution**:
  - High Priority: 126 entries (46.7%)
  - Medium Priority: 86 entries (31.9%)
  - Low Priority: 58 entries (21.4%)

### Top Tags

1. `datadog` (270) - All entries related to Datadog
2. `integration` (264) - Integration-related topics  
3. `mulesoft` (261) - MuleSoft-specific information
4. `configuration` (210) - Configuration and setup
5. `activation` (176) - Product activation procedures
6. `troubleshooting` (48) - Problem resolution
7. `deployment` (33) - Deployment scenarios
8. `network` (24) - Network-related issues
9. `authentication` (11) - Authentication topics
10. `version` (6) - Version-specific information

### Content Processing

The knowledge base was processed from raw support emails using an automated enhancement pipeline that:

1. **Extracts Structure**: Parses Title, Description, Problem, and Resolution from raw content
2. **Generates Tags**: Automatically assigns relevant tags based on content analysis
3. **Determines Priority**: Assigns priority levels based on keyword analysis and impact
4. **Creates Q&A Format**: Converts structured data into question-answer pairs
5. **Enhances Searchability**: Optimizes content for vector similarity search

## Deployment

### Prerequisites

1. **AWS Infrastructure**: Ensure the NovaBot Terraform infrastructure is deployed
2. **S3 Bucket**: The knowledge base S3 bucket should be created
3. **Bedrock Knowledge Base**: Amazon Bedrock Knowledge Base should be configured

### Deployment Steps

1. **Upload to S3**: Use the deployment script to upload knowledge base files
   ```bash
   ./scripts/deploy_knowledge_base.sh
   ```

2. **Sync Knowledge Base**: Trigger Amazon Bedrock Knowledge Base sync
   ```bash
   aws bedrock-agent start-ingestion-job \
     --knowledge-base-id <your-kb-id> \
     --data-source-id <your-data-source-id>
   ```

3. **Verify Deployment**: Test the knowledge base integration
   ```bash
   ./scripts/test_knowledge_base.sh
   ```

### Manual Deployment

If you prefer manual deployment:

```bash
# Get the S3 bucket name from Terraform outputs
BUCKET_NAME=$(terraform output -raw knowledge_base_s3_bucket_name)

# Upload knowledge base files
aws s3 cp data/knowledge_base/ s3://$BUCKET_NAME/knowledge_base/ --recursive

# Verify upload
aws s3 ls s3://$BUCKET_NAME/knowledge_base/ --human-readable
```

## Knowledge Base Management

### Adding New Content

1. Create or update CSV files following the standard format
2. Use the processing scripts in `scripts/` to validate and enhance content
3. Deploy using the deployment scripts
4. Trigger Knowledge Base sync in AWS console or CLI

### Content Guidelines

- **Questions**: Should be clear, specific, and reflect real user inquiries
- **Answers**: Should be comprehensive, actionable, and include step-by-step instructions
- **Categories**: Use consistent categorization for better organization
- **Tags**: Include relevant, searchable keywords
- **Priority**: Assign based on user impact and urgency

### Quality Standards

- All content should be verified and accurate
- Include relevant URLs and documentation references
- Use consistent formatting and terminology
- Provide context-aware responses
- Include error codes and specific technical details when relevant

## Monitoring and Analytics

### Key Metrics to Track

1. **Query Performance**: Response time and accuracy
2. **Content Effectiveness**: Which articles are most/least accessed
3. **Knowledge Gaps**: Queries that don't find relevant matches
4. **User Satisfaction**: Feedback on answer quality

### Optimization Strategies

1. **Regular Updates**: Keep content current with product changes
2. **Gap Analysis**: Identify and fill knowledge gaps
3. **Performance Tuning**: Optimize vector embeddings and search parameters
4. **User Feedback**: Incorporate user feedback to improve content quality

## Integration with NovaBot

The knowledge base integrates with NovaBot through:

1. **Amazon Bedrock Knowledge Base**: Provides RAG capabilities
2. **Vector Search**: Enables semantic search across content
3. **Context-Aware Responses**: Delivers relevant information based on user queries
4. **Multi-Modal Support**: Handles text-based queries with rich context

## File Validation

Use the provided validation scripts to ensure data quality:

```bash
# Validate CSV format and content
python scripts/validate_knowledge_base.py

# Check for duplicates and inconsistencies  
python scripts/check_knowledge_base_quality.py

# Generate analytics and reports
python scripts/analyze_knowledge_base.py
```

## Support

For questions about the knowledge base:

1. Check this documentation
2. Review the validation scripts
3. Test with the provided tools
4. Contact the NovaBot development team

---

**Last Updated**: January 2025  
**Version**: 2.0  
**Maintainer**: NovaBot Team