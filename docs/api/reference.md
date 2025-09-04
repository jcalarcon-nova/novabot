# API Reference

This document provides comprehensive reference for the NovaBot API endpoints, request/response formats, and integration patterns.

## 🔗 Base URL

```
Production: https://your-api-gateway-url
Development: https://your-dev-api-gateway-url
```

## 🔐 Authentication

NovaBot API uses AWS API Gateway without additional authentication for public endpoints. For production deployments, consider implementing:

- API Keys for rate limiting
- AWS Cognito for user authentication
- IAM authentication for service-to-service calls

## 📋 API Endpoints

### Chat Endpoint

#### `POST /chat`

Send a message to the NovaBot AI assistant and receive a response.

**Request Headers:**
```http
Content-Type: application/json
Origin: https://your-domain.com  # Required for CORS
```

**Request Body:**
```json
{
  "message": "string",           // Required: User message (max 4000 characters)
  "sessionId": "string",         // Optional: Session ID for conversation continuity
  "userId": "string",            // Optional: User identifier
  "context": {                   // Optional: Additional context
    "page": "string",            // Current page URL
    "userAgent": "string",       // Browser user agent
    "timestamp": "string"        // ISO 8601 timestamp
  },
  "streaming": boolean           // Optional: Enable streaming responses (default: false)
}
```

**Response (Non-streaming):**
```json
{
  "response": "string",          // AI assistant response
  "sessionId": "string",         // Session ID for continuation
  "timestamp": "string",         // Response timestamp (ISO 8601)
  "confidence": number,          // Response confidence score (0-1)
  "sources": [                   // Knowledge base sources used
    {
      "title": "string",
      "excerpt": "string",
      "score": number
    }
  ],
  "actions": [                   // Available follow-up actions
    {
      "type": "create_ticket",
      "label": "Create Support Ticket",
      "enabled": boolean
    }
  ],
  "metadata": {
    "processingTime": number,    // Processing time in milliseconds
    "tokensUsed": number,        // Tokens consumed
    "modelUsed": "string"        // AI model identifier
  }
}
```

**Response (Streaming):**
```http
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive

data: {"type": "start", "sessionId": "session-123"}

data: {"type": "content", "content": "Hello! How"}

data: {"type": "content", "content": " can I help you today?"}

data: {"type": "sources", "sources": [...]}

data: {"type": "end", "metadata": {...}}
```

**Error Response:**
```json
{
  "error": {
    "code": "string",            // Error code (see Error Codes section)
    "message": "string",         // Human-readable error message
    "details": "string",         // Additional error details
    "timestamp": "string",       // Error timestamp
    "requestId": "string"        // Request ID for troubleshooting
  }
}
```

**Status Codes:**
- `200 OK`: Successful response
- `400 Bad Request`: Invalid request format or parameters
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

**Example Request:**
```bash
curl -X POST "https://your-api-gateway-url/chat" \
  -H "Content-Type: application/json" \
  -H "Origin: https://your-website.com" \
  -d '{
    "message": "How do I reset my password?",
    "sessionId": "session-123",
    "userId": "user-456",
    "streaming": false
  }'
```

**Example Response:**
```json
{
  "response": "To reset your password: 1) Go to the login page 2) Click 'Forgot Password' 3) Enter your email address...",
  "sessionId": "session-123",
  "timestamp": "2024-01-15T10:30:00Z",
  "confidence": 0.95,
  "sources": [
    {
      "title": "Password Reset FAQ",
      "excerpt": "To reset your password: 1) Go to the login page...",
      "score": 0.89
    }
  ],
  "actions": [
    {
      "type": "create_ticket",
      "label": "Need more help?",
      "enabled": true
    }
  ],
  "metadata": {
    "processingTime": 1250,
    "tokensUsed": 156,
    "modelUsed": "claude-3.5-sonnet"
  }
}
```

### Health Check Endpoint

#### `GET /health`

Check the API service health and status.

**Response:**
```json
{
  "status": "healthy",           // Service status: healthy, degraded, unhealthy
  "timestamp": "string",         // Current timestamp
  "version": "string",           // API version
  "services": {
    "bedrock": "healthy",        // Bedrock service status
    "lambda": "healthy",         // Lambda function status
    "knowledgeBase": "healthy"   // Knowledge base status
  },
  "uptime": number              // Uptime in seconds
}
```

### Create Ticket Endpoint

#### `POST /create-ticket`

Create a support ticket in Zendesk (called internally by the AI agent).

**Request Body:**
```json
{
  "subject": "string",           // Required: Ticket subject
  "description": "string",       // Required: Ticket description
  "priority": "string",          // Optional: low, normal, high, urgent (default: normal)
  "type": "string",             // Optional: question, incident, problem, task
  "tags": ["string"],           // Optional: Array of tags
  "customFields": {             // Optional: Custom field values
    "field_id": "value"
  },
  "requester": {                // Optional: Requester information
    "name": "string",
    "email": "string"
  }
}
```

**Response:**
```json
{
  "ticketId": "string",          // Created ticket ID
  "ticketUrl": "string",         // Direct link to ticket
  "status": "created",           // Ticket status
  "timestamp": "string"          // Creation timestamp
}
```

## 🔄 Streaming Responses

NovaBot supports real-time streaming responses for a better user experience.

### Server-Sent Events Format

When `streaming: true` is specified, the API returns Server-Sent Events:

```javascript
// Client-side JavaScript example
const eventSource = new EventSource('https://api-url/chat-stream');

eventSource.onmessage = function(event) {
  const data = JSON.parse(event.data);
  
  switch(data.type) {
    case 'start':
      console.log('Conversation started:', data.sessionId);
      break;
      
    case 'content':
      // Append content to chat interface
      appendToChatMessage(data.content);
      break;
      
    case 'sources':
      // Display knowledge sources
      displaySources(data.sources);
      break;
      
    case 'actions':
      // Show available actions
      showActions(data.actions);
      break;
      
    case 'end':
      // Response complete
      finalizeMessage(data.metadata);
      eventSource.close();
      break;
      
    case 'error':
      // Handle errors
      showError(data.error);
      eventSource.close();
      break;
  }
};
```

### Event Types

| Type | Description | Data |
|------|-------------|------|
| `start` | Response streaming initiated | `{sessionId}` |
| `content` | Partial response content | `{content}` |
| `sources` | Knowledge base sources | `{sources: [...]}` |
| `actions` | Available follow-up actions | `{actions: [...]}` |
| `metadata` | Processing metadata | `{processingTime, tokensUsed, ...}` |
| `end` | Response complete | `{metadata}` |
| `error` | Error occurred | `{error}` |

## 📊 Rate Limiting

Default rate limits (configurable):

| Endpoint | Limit | Window |
|----------|-------|---------|
| `/chat` | 60 requests | 1 minute |
| `/create-ticket` | 10 requests | 1 minute |
| `/health` | 1000 requests | 1 minute |

**Rate Limit Headers:**
```http
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1642248600
```

**Rate Limit Exceeded Response:**
```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests",
    "retryAfter": 60
  }
}
```

## 🚫 Error Codes

| Code | Description | HTTP Status | Solution |
|------|-------------|-------------|----------|
| `INVALID_REQUEST` | Malformed request | 400 | Check request format |
| `MISSING_PARAMETER` | Required parameter missing | 400 | Include all required fields |
| `INVALID_PARAMETER` | Parameter validation failed | 400 | Check parameter values |
| `RATE_LIMIT_EXCEEDED` | Too many requests | 429 | Implement exponential backoff |
| `BEDROCK_ERROR` | Bedrock service error | 500 | Retry request |
| `KNOWLEDGE_BASE_ERROR` | Knowledge base unavailable | 500 | Check knowledge base status |
| `ZENDESK_ERROR` | Zendesk integration error | 500 | Check Zendesk credentials |
| `INTERNAL_ERROR` | Unexpected server error | 500 | Contact support |

## 🔌 SDK Examples

### JavaScript/TypeScript

```typescript
interface ChatRequest {
  message: string;
  sessionId?: string;
  userId?: string;
  streaming?: boolean;
}

interface ChatResponse {
  response: string;
  sessionId: string;
  timestamp: string;
  confidence: number;
  sources?: Array<{
    title: string;
    excerpt: string;
    score: number;
  }>;
  actions?: Array<{
    type: string;
    label: string;
    enabled: boolean;
  }>;
}

class NovaBotClient {
  private baseUrl: string;
  
  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }
  
  async sendMessage(request: ChatRequest): Promise<ChatResponse> {
    const response = await fetch(`${this.baseUrl}/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(request)
    });
    
    if (!response.ok) {
      throw new Error(`API error: ${response.status}`);
    }
    
    return response.json();
  }
  
  async sendMessageStreaming(request: ChatRequest, onChunk: (chunk: any) => void): Promise<void> {
    const response = await fetch(`${this.baseUrl}/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({...request, streaming: true})
    });
    
    const reader = response.body?.getReader();
    if (!reader) throw new Error('No response body');
    
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      
      const chunk = new TextDecoder().decode(value);
      const lines = chunk.split('\n');
      
      for (const line of lines) {
        if (line.startsWith('data: ')) {
          const data = JSON.parse(line.substring(6));
          onChunk(data);
        }
      }
    }
  }
}
```

### Python

```python
import requests
import json
from typing import Optional, Dict, Any, Generator

class NovaBotClient:
    def __init__(self, base_url: str):
        self.base_url = base_url
    
    def send_message(self, 
                    message: str, 
                    session_id: Optional[str] = None,
                    user_id: Optional[str] = None,
                    streaming: bool = False) -> Dict[str, Any]:
        """Send a message to NovaBot."""
        
        payload = {
            "message": message,
            "streaming": streaming
        }
        
        if session_id:
            payload["sessionId"] = session_id
        if user_id:
            payload["userId"] = user_id
        
        response = requests.post(
            f"{self.base_url}/chat",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        
        response.raise_for_status()
        return response.json()
    
    def send_message_streaming(self, 
                             message: str,
                             session_id: Optional[str] = None) -> Generator[Dict[str, Any], None, None]:
        """Send a message with streaming response."""
        
        payload = {
            "message": message,
            "streaming": True
        }
        
        if session_id:
            payload["sessionId"] = session_id
        
        response = requests.post(
            f"{self.base_url}/chat",
            json=payload,
            headers={"Content-Type": "application/json"},
            stream=True
        )
        
        response.raise_for_status()
        
        for line in response.iter_lines():
            if line:
                decoded_line = line.decode('utf-8')
                if decoded_line.startswith('data: '):
                    yield json.loads(decoded_line[6:])

# Example usage
client = NovaBotClient("https://your-api-gateway-url")

# Non-streaming
response = client.send_message("How do I reset my password?")
print(response["response"])

# Streaming
for chunk in client.send_message_streaming("How do I reset my password?"):
    if chunk.get("type") == "content":
        print(chunk["content"], end="")
```

### cURL Examples

```bash
# Basic chat request
curl -X POST "https://your-api-gateway-url/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello, I need help with my account",
    "sessionId": "session-123"
  }'

# Health check
curl -X GET "https://your-api-gateway-url/health"

# Create ticket (internal use)
curl -X POST "https://your-api-gateway-url/create-ticket" \
  -H "Content-Type: application/json" \
  -d '{
    "subject": "Account Access Issue",
    "description": "User cannot log into their account",
    "priority": "high",
    "requester": {
      "name": "John Doe",
      "email": "john@example.com"
    }
  }'
```

## 🔗 Webhook Integration

For advanced integrations, NovaBot can send webhooks for various events:

### Webhook Events

| Event | Description | Payload |
|-------|-------------|---------|
| `conversation.started` | New conversation initiated | `{sessionId, userId, timestamp}` |
| `conversation.ended` | Conversation completed | `{sessionId, userId, duration, messageCount}` |
| `ticket.created` | Support ticket created | `{ticketId, subject, priority, timestamp}` |
| `error.occurred` | System error occurred | `{error, context, timestamp}` |

### Webhook Configuration

Configure webhooks in your Terraform variables:

```hcl
webhook_config = {
  enabled = true
  url = "https://your-webhook-endpoint.com/novabot"
  events = ["conversation.started", "ticket.created"]
  secret = "your-webhook-secret"
}
```

## 📈 Monitoring and Analytics

### API Metrics

Key metrics available in CloudWatch:

- `RequestCount`: Total API requests
- `ErrorRate`: Percentage of failed requests
- `ResponseTime`: Average response time
- `TokenUsage`: Bedrock token consumption
- `KnowledgeBaseQueries`: Knowledge base query count

### Custom Headers for Tracking

Include these headers for enhanced monitoring:

```http
X-Request-ID: unique-request-identifier
X-User-ID: user-identifier
X-Session-ID: session-identifier
X-Source: web-widget|api|mobile
```

## 🛡️ Security Considerations

### Best Practices

1. **Rate Limiting**: Implement client-side rate limiting
2. **Input Validation**: Validate all inputs before sending
3. **HTTPS Only**: Always use HTTPS endpoints
4. **Error Handling**: Don't expose sensitive error details
5. **Logging**: Log requests for monitoring (without PII)

### CORS Configuration

For web applications, ensure proper CORS setup:

```javascript
// API Gateway CORS configuration
{
  "allowOrigins": ["https://your-domain.com"],
  "allowMethods": ["POST", "GET", "OPTIONS"],
  "allowHeaders": ["Content-Type", "X-Requested-With"],
  "maxAge": 86400
}
```

## 📝 API Versioning

Current API version: `v1`

Future versions will be available at:
- `https://your-api-gateway-url/v2/...`

Version compatibility:
- `v1`: Current stable version
- Deprecated versions supported for 12 months
- Breaking changes require new major version

---

For additional support or questions about the API, please refer to the [troubleshooting guide](../troubleshooting/common-issues.md) or create an issue in the GitHub repository.