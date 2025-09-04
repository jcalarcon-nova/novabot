# NovaBot Project Overview

## Purpose
NovaBot is a comprehensive AWS Bedrock-powered support chatbot system that provides end-to-end Infrastructure-as-Code (IaC) implementation using Terraform. The system features Knowledge Base RAG, Zendesk ticket creation, and a web widget interface.

## Core Components

### 1. AWS Bedrock Integration
- **Bedrock Agents** with OpenAPI-defined Actions
- **Knowledge Bases** using S3 Vectors for RAG functionality
- **InvokeAgent** API for streaming responses

### 2. Integrations
- **Zendesk API** for automated ticket creation
- **Web Widget** with real-time streaming responses
- **CSV-based knowledge ingestion** from S3

### 3. Infrastructure
- **Complete Terraform IaC** with modular architecture
- **AWS Lambda functions** for business logic
- **API Gateway HTTP API** for web integration
- **Amazon Connect scaffolding** (future-ready for omni-channel)

### 4. Security & Operations
- **IAM roles and policies** with least privilege
- **AWS Secrets Manager** for credential management
- **CloudWatch Logs** for observability
- **CI/CD pipeline** with GitHub Actions

## Key Features
- Real-time streaming chatbot responses
- Automated support ticket creation
- Knowledge base powered by company documentation
- Scalable serverless architecture
- Multi-environment support (dev/prod)
- Future-ready for Amazon Connect integration

## Architecture Pattern
- **Serverless-first** design using AWS Lambda
- **Event-driven** with API Gateway and Bedrock
- **Infrastructure as Code** with Terraform modules
- **Security by design** with proper IAM and secrets management