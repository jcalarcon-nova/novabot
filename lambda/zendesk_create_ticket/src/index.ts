import { Handler, Context } from 'aws-lambda';
import fetch from 'node-fetch';
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

const secretsClient = new SecretsManagerClient({ region: process.env.AWS_REGION });

interface BedrockActionEvent {
  body: string;
  httpMethod: string;
  apiPath: string;
  messageVersion: string;
  requestId: string;
  inputText: string;
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

interface ZendeskCredentials {
  subdomain: string;
  email: string;
  api_token: string;
  plugin_version_field_id?: string;
  mule_runtime_field_id?: string;
}

interface ZendeskTicketResponse {
  ticket: {
    id: number;
    url: string;
    status: string;
  };
}

async function getZendeskCredentials(): Promise<ZendeskCredentials> {
  try {
    const command = new GetSecretValueCommand({
      SecretId: process.env.ZENDESK_SECRET_NAME || 'novabot-zendesk-credentials'
    });
    
    const response = await secretsClient.send(command);
    
    if (!response.SecretString) {
      throw new Error('No secret string found in Secrets Manager response');
    }
    
    return JSON.parse(response.SecretString) as ZendeskCredentials;
  } catch (error) {
    console.error('Error retrieving Zendesk credentials:', error);
    throw new Error('Failed to retrieve Zendesk credentials from Secrets Manager');
  }
}

async function createZendeskTicket(
  ticketRequest: TicketRequest, 
  credentials: ZendeskCredentials
): Promise<ZendeskTicketResponse> {
  const authToken = Buffer.from(
    `${credentials.email}/token:${credentials.api_token}`
  ).toString('base64');
  
  const customFields = [];
  
  if (ticketRequest.plugin_version && credentials.plugin_version_field_id) {
    customFields.push({
      id: credentials.plugin_version_field_id,
      value: ticketRequest.plugin_version
    });
  }
  
  if (ticketRequest.mule_runtime && credentials.mule_runtime_field_id) {
    customFields.push({
      id: credentials.mule_runtime_field_id,
      value: ticketRequest.mule_runtime
    });
  }
  
  const payload = {
    ticket: {
      requester: { 
        email: ticketRequest.requester_email 
      },
      subject: ticketRequest.subject,
      comment: { 
        body: ticketRequest.description 
      },
      priority: ticketRequest.priority || 'normal',
      tags: ticketRequest.tags || ['novabot', 'automated'],
      ...(customFields.length > 0 && { custom_fields: customFields })
    }
  };
  
  const zendeskUrl = `https://${credentials.subdomain}.zendesk.com/api/v2/tickets.json`;
  
  console.log(`Creating ticket via Zendesk API: ${zendeskUrl}`);
  console.log('Ticket payload:', JSON.stringify(payload, null, 2));
  
  try {
    const response = await fetch(zendeskUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${authToken}`,
        'User-Agent': 'NovaBot/1.0'
      },
      body: JSON.stringify(payload),
      timeout: 30000
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      console.error(`Zendesk API error: ${response.status} - ${errorText}`);
      throw new Error(`Zendesk API error: ${response.status} - ${response.statusText}`);
    }
    
    const result = await response.json() as ZendeskTicketResponse;
    console.log('Ticket created successfully:', result.ticket.id);
    
    return result;
  } catch (error) {
    console.error('Error calling Zendesk API:', error);
    throw new Error(`Failed to create Zendesk ticket: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
}

function validateTicketRequest(request: any): request is TicketRequest {
  if (!request.requester_email || !request.subject || !request.description) {
    return false;
  }
  
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(request.requester_email)) {
    return false;
  }
  
  return true;
}

export const handler: Handler = async (event: BedrockActionEvent, context: Context) => {
  console.log('Received event:', JSON.stringify(event, null, 2));
  console.log('Context:', JSON.stringify(context, null, 2));
  
  try {
    let ticketRequest: TicketRequest;
    
    // Handle different event formats
    if (event.body) {
      // Standard API Gateway format
      ticketRequest = JSON.parse(event.body);
    } else if (event.inputText) {
      // Bedrock Agent format - try to parse structured input
      try {
        ticketRequest = JSON.parse(event.inputText);
      } catch {
        // If parsing fails, create a simple ticket from the input text
        ticketRequest = {
          requester_email: 'support@example.com', // Default - should be overridden
          subject: 'Support Request from NovaBot',
          description: event.inputText
        };
      }
    } else {
      // Direct invocation with event as ticket request
      ticketRequest = event as any;
    }
    
    // Validate the ticket request
    if (!validateTicketRequest(ticketRequest)) {
      console.error('Invalid ticket request:', ticketRequest);
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          error: 'Invalid ticket request',
          message: 'Missing required fields: requester_email, subject, description'
        })
      };
    }
    
    // Retrieve Zendesk credentials
    const credentials = await getZendeskCredentials();
    
    // Create the ticket
    const result = await createZendeskTicket(ticketRequest, credentials);
    
    // Return success response
    const response = {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        ticket_id: result.ticket.id.toString(),
        ticket_url: result.ticket.url,
        status: 'created',
        message: `Ticket ${result.ticket.id} created successfully`
      })
    };
    
    console.log('Returning response:', JSON.stringify(response, null, 2));
    return response;
    
  } catch (error) {
    console.error('Error in Lambda handler:', error);
    
    const errorResponse = {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error occurred'
      })
    };
    
    console.log('Returning error response:', JSON.stringify(errorResponse, null, 2));
    return errorResponse;
  }
};