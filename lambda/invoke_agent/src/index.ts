import { Handler, APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { 
  BedrockAgentRuntimeClient, 
  InvokeAgentCommand,
  InvokeAgentCommandInput,
  InvokeAgentCommandOutput
} from '@aws-sdk/client-bedrock-agent-runtime';

const bedrockClient = new BedrockAgentRuntimeClient({ 
  region: process.env.AWS_REGION || 'us-east-1' 
});

interface InvokeAgentRequest {
  sessionId: string;
  inputText: string;
  sessionAttributes?: Record<string, string>;
  enableTrace?: boolean;
}

interface BedrockAgentResponse {
  sessionId: string;
  completion: string;
  traces?: unknown[];
  citations?: unknown[];
}

function generateSessionId(): string {
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 15);
  return `session_${timestamp}_${random}`;
}

function validateRequest(body: unknown): body is InvokeAgentRequest {
  if (!body || typeof body !== 'object') return false;
  
  const bodyObj = body as any;
  
  // sessionId is optional - will be generated if not provided
  if (!bodyObj.inputText || typeof bodyObj.inputText !== 'string') {
    return false;
  }
  
  if (bodyObj.inputText.trim().length === 0) {
    return false;
  }
  
  return true;
}

async function processBedrockAgentStream(
  response: InvokeAgentCommandOutput
): Promise<BedrockAgentResponse> {
  const chunks: string[] = [];
  const traces: unknown[] = [];
  const citations: unknown[] = [];
  let sessionId = '';
  
  if (!response.completion) {
    throw new Error('No completion stream received from Bedrock agent');
  }
  
  try {
    for await (const chunk of response.completion) {
      console.log('Received chunk:', JSON.stringify(chunk, null, 2));
      
      if (chunk.chunk?.bytes) {
        const chunkText = new TextDecoder().decode(chunk.chunk.bytes);
        chunks.push(chunkText);
      }
      
      if (chunk.trace) {
        traces.push(chunk.trace);
      }
      
      if (chunk.chunk?.attribution?.citations) {
        citations.push(...chunk.chunk.attribution.citations);
      }
    }
    
    sessionId = response.sessionId || '';
    
    return {
      sessionId,
      completion: chunks.join(''),
      traces: traces.length > 0 ? traces : undefined,
      citations: citations.length > 0 ? citations : undefined
    };
    
  } catch (error) {
    console.error('Error processing Bedrock agent stream:', error);
    throw new Error('Failed to process streaming response from Bedrock agent');
  }
}

function createCORSHeaders(): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': '*', // In production, use specific origins
    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
    'Access-Control-Allow-Methods': 'OPTIONS,POST',
    'Content-Type': 'application/json'
  };
}

function createErrorResponse(statusCode: number, message: string, error?: unknown): APIGatewayProxyResult {
  console.error('Error response:', { statusCode, message, error });
  
  const responseBody: any = {
    error: message,
    timestamp: new Date().toISOString()
  };

  if (error && process.env.NODE_ENV !== 'production') {
    responseBody.details = error instanceof Error ? error.message : String(error);
  }
  
  return {
    statusCode,
    headers: createCORSHeaders(),
    body: JSON.stringify(responseBody)
  };
}

export const handler: Handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  console.log('Received event:', JSON.stringify(event, null, 2));
  
  // Handle CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: createCORSHeaders(),
      body: ''
    };
  }
  
  // Only accept POST requests
  if (event.httpMethod !== 'POST') {
    return createErrorResponse(405, 'Method not allowed');
  }
  
  try {
    // Parse request body
    if (!event.body) {
      return createErrorResponse(400, 'Request body is required');
    }
    
    let requestBody: InvokeAgentRequest;
    try {
      requestBody = JSON.parse(event.body);
    } catch (parseError) {
      return createErrorResponse(400, 'Invalid JSON in request body');
    }
    
    // Validate request
    if (!validateRequest(requestBody)) {
      return createErrorResponse(400, 'Invalid request format. Required: inputText (string)');
    }
    
    // Generate session ID if not provided
    const sessionId = requestBody.sessionId || generateSessionId();
    
    // Prepare Bedrock agent invocation
    const agentId = process.env.BEDROCK_AGENT_ID;
    const agentAliasId = process.env.BEDROCK_AGENT_ALIAS_ID;
    
    if (!agentId || !agentAliasId) {
      return createErrorResponse(500, 'Bedrock agent configuration not found');
    }
    
    const params: InvokeAgentCommandInput = {
      agentId,
      agentAliasId,
      sessionId,
      inputText: requestBody.inputText.trim(),
      ...(requestBody.sessionAttributes && { sessionAttributes: requestBody.sessionAttributes }),
      ...(requestBody.enableTrace && { enableTrace: requestBody.enableTrace })
    };
    
    console.log('Invoking Bedrock agent with params:', {
      agentId,
      agentAliasId,
      sessionId,
      inputText: requestBody.inputText,
      enableTrace: requestBody.enableTrace || false
    });
    
    // Invoke Bedrock agent
    const command = new InvokeAgentCommand(params);
    const response = await bedrockClient.send(command);
    
    // Process streaming response
    const agentResponse = await processBedrockAgentStream(response);
    
    console.log('Bedrock agent response processed successfully:', {
      sessionId: agentResponse.sessionId,
      completionLength: agentResponse.completion.length,
      hasTraces: !!agentResponse.traces,
      hasCitations: !!agentResponse.citations
    });
    
    // Return successful response
    return {
      statusCode: 200,
      headers: createCORSHeaders(),
      body: JSON.stringify({
        sessionId: agentResponse.sessionId,
        completion: agentResponse.completion,
        ...(agentResponse.traces && { traces: agentResponse.traces }),
        ...(agentResponse.citations && { citations: agentResponse.citations }),
        timestamp: new Date().toISOString()
      })
    };
    
  } catch (error) {
    console.error('Error in invoke-agent handler:', error);
    
    // Handle specific AWS SDK errors
    if (error instanceof Error) {
      if (error.name === 'ValidationException') {
        return createErrorResponse(400, 'Invalid request parameters', error);
      }
      
      if (error.name === 'ResourceNotFoundException') {
        return createErrorResponse(404, 'Bedrock agent not found', error);
      }
      
      if (error.name === 'AccessDeniedException') {
        return createErrorResponse(403, 'Access denied to Bedrock agent', error);
      }
      
      if (error.name === 'ThrottlingException') {
        return createErrorResponse(429, 'Request rate limit exceeded', error);
      }
      
      if (error.name === 'ServiceUnavailableException') {
        return createErrorResponse(503, 'Bedrock service temporarily unavailable', error);
      }
    }
    
    // Generic error response
    return createErrorResponse(500, 'Internal server error', error);
  }
};