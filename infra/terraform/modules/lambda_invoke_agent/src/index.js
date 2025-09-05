const { 
  BedrockAgentRuntimeClient, 
  InvokeAgentCommand 
} = require('@aws-sdk/client-bedrock-agent-runtime');

// Initialize Bedrock Agent client
const bedrockAgentClient = new BedrockAgentRuntimeClient({
  region: process.env.AWS_REGION || 'us-east-1',
});

/**
 * Lambda handler for invoking Bedrock Agent
 * Supports both streaming and non-streaming responses
 */
exports.handler = async (event) => {
  console.log('Bedrock Agent Lambda invoked');
  console.log('Event:', JSON.stringify(event, null, 2));
  
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent,X-Requested-With',
    'Access-Control-Allow-Methods': 'GET,HEAD,OPTIONS,POST',
    'Content-Type': 'application/json'
  };

  // Handle OPTIONS preflight requests
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: ''
    };
  }

  try {
    // Parse request body
    let requestBody;
    try {
      requestBody = typeof event.body === 'string' 
        ? JSON.parse(event.body) 
        : event.body;
    } catch (parseError) {
      console.error('Error parsing request body:', parseError);
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Invalid JSON in request body',
          timestamp: new Date().toISOString()
        })
      };
    }

    // Validate required fields
    const { sessionId, inputText, sessionAttributes = {}, enableStreaming = false } = requestBody;
    
    if (!sessionId || !inputText) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Missing required fields: sessionId and inputText',
          timestamp: new Date().toISOString()
        })
      };
    }

    // Check if Bedrock agent is configured
    const agentId = process.env.BEDROCK_AGENT_ID;
    const agentAliasId = process.env.BEDROCK_AGENT_ALIAS_ID;
    
    if (!agentId || !agentAliasId) {
      console.error('Bedrock agent configuration missing:', { agentId, agentAliasId });
      return {
        statusCode: 500,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Bedrock agent configuration not found',
          timestamp: new Date().toISOString()
        })
      };
    }

    console.log('Invoking Bedrock Agent:', { agentId, agentAliasId, sessionId });

    // Prepare invoke agent command
    const command = new InvokeAgentCommand({
      agentId: agentId,
      agentAliasId: agentAliasId,
      sessionId: sessionId,
      inputText: inputText,
      sessionState: {
        sessionAttributes: {
          ...sessionAttributes,
          timestamp: new Date().toISOString(),
          userAgent: event.requestContext?.identity?.userAgent || 'unknown',
          sourceIP: event.requestContext?.identity?.sourceIp || 'unknown'
        }
      },
      // Enable trace for debugging (disable in production)
      enableTrace: process.env.NODE_ENV !== 'prod'
    });

    // Check if streaming is requested and supported
    if (enableStreaming && event.headers?.Accept?.includes('text/event-stream')) {
      // Return streaming response
      return handleStreamingResponse(command);
    } else {
      // Return regular JSON response
      return handleRegularResponse(command, corsHeaders);
    }

  } catch (error) {
    console.error('Error invoking Bedrock Agent:', error);
    
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Internal server error',
        message: process.env.NODE_ENV === 'prod' ? 'Something went wrong' : error.message,
        timestamp: new Date().toISOString()
      })
    };
  }
};

/**
 * Handle streaming response using Server-Sent Events
 */
async function handleStreamingResponse(command) {
  // Note: AWS Lambda doesn't support true streaming responses yet
  // This would need API Gateway with Lambda streaming support
  // For now, we'll simulate streaming by chunking the response
  
  console.log('Streaming mode requested - using chunked response simulation');
  
  try {
    const response = await bedrockAgentClient.send(command);
    
    let fullResponse = '';
    const chunks = [];
    let sessionId = null;
    let citations = [];
    let traces = [];

    // Process the streaming response
    if (response.completion) {
      for await (const chunk of response.completion) {
        if (chunk.chunk) {
          const chunkText = new TextDecoder().decode(chunk.chunk.bytes);
          fullResponse += chunkText;
          chunks.push({
            type: 'token',
            content: chunkText,
            timestamp: new Date().toISOString()
          });
        }
        
        if (chunk.sessionAttributes) {
          sessionId = chunk.sessionAttributes.sessionId;
        }
        
        if (chunk.citations) {
          citations = citations.concat(chunk.citations);
        }
      }
    }

    // For now, return as JSON with chunked data
    // This can be enhanced when Lambda streaming is available
    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'OPTIONS,POST',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        completion: fullResponse,
        chunks: chunks,
        citations: citations,
        traces: traces,
        sessionId: sessionId,
        streaming: true,
        timestamp: new Date().toISOString()
      })
    };

  } catch (error) {
    console.error('Streaming error:', error);
    throw error;
  }
}

/**
 * Handle regular JSON response
 */
async function handleRegularResponse(command, corsHeaders) {
  try {
    const response = await bedrockAgentClient.send(command);
    
    let completion = '';
    let sessionId = null;
    let citations = [];
    let traces = [];

    // Process the response stream
    if (response.completion) {
      for await (const chunk of response.completion) {
        if (chunk.chunk) {
          completion += new TextDecoder().decode(chunk.chunk.bytes);
        }
        
        if (chunk.sessionAttributes) {
          sessionId = chunk.sessionAttributes.sessionId;
        }
        
        if (chunk.citations) {
          citations = citations.concat(chunk.citations);
        }
        
        if (chunk.trace) {
          traces.push(chunk.trace);
        }
      }
    }

    console.log('Bedrock Agent response received:', {
      completion: completion.substring(0, 100) + '...',
      sessionId,
      citationsCount: citations.length,
      tracesCount: traces.length
    });

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        completion: completion,
        citations: citations,
        traces: traces,
        sessionId: sessionId,
        timestamp: new Date().toISOString()
      })
    };

  } catch (error) {
    console.error('Regular response error:', error);
    throw error;
  }
}