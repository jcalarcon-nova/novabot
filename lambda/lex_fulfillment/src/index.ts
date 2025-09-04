import { Handler, Context } from 'aws-lambda';
import { 
  BedrockAgentRuntimeClient, 
  InvokeAgentCommand,
  InvokeAgentCommandInput
} from '@aws-sdk/client-bedrock-agent-runtime';

const bedrockClient = new BedrockAgentRuntimeClient({ 
  region: process.env.AWS_REGION || 'us-east-1' 
});

// Lex V2 Event interfaces
interface LexV2Event {
  messageVersion: string;
  invocationSource: 'DialogCodeHook' | 'FulfillmentCodeHook';
  inputMode: 'Text' | 'Speech' | 'DTMF';
  responseContentType: string;
  sessionId: string;
  inputTranscript: string;
  bot: {
    id: string;
    name: string;
    version: string;
    localeId: string;
  };
  interpretations: Array<{
    intent: {
      confirmationState: 'Confirmed' | 'Denied' | 'None';
      name: string;
      slots: Record<string, {
        value?: {
          interpretedValue: string;
          originalValue: string;
          resolvedValues: string[];
        };
      }>;
      state: 'Failed' | 'Fulfilled' | 'InProgress' | 'ReadyForFulfillment';
    };
    nluConfidence?: {
      score: number;
    };
  }>;
  proposedNextState?: {
    intent: {
      name: string;
      slots: Record<string, any>;
      state: string;
    };
    dialogAction: {
      type: string;
    };
  };
  requestAttributes?: Record<string, string>;
  sessionState: {
    dialogAction?: {
      slotToElicit?: string;
      type: 'Close' | 'ConfirmIntent' | 'Delegate' | 'ElicitIntent' | 'ElicitSlot';
    };
    intent: {
      confirmationState: 'Confirmed' | 'Denied' | 'None';
      name: string;
      slots: Record<string, any>;
      state: 'Failed' | 'Fulfilled' | 'InProgress' | 'ReadyForFulfillment';
    };
    originatingRequestId?: string;
  };
}

interface LexV2Response {
  sessionState: {
    dialogAction: {
      type: 'Close' | 'ConfirmIntent' | 'Delegate' | 'ElicitIntent' | 'ElicitSlot';
      fulfillmentState?: 'Failed' | 'Fulfilled' | 'InProgress';
      slotToElicit?: string;
    };
    intent: {
      confirmationState?: 'Confirmed' | 'Denied' | 'None';
      name: string;
      slots?: Record<string, any>;
      state: 'Failed' | 'Fulfilled' | 'InProgress' | 'ReadyForFulfillment';
    };
  };
  messages?: Array<{
    contentType: 'PlainText' | 'ImageResponseCard' | 'CustomPayload';
    content: string;
  }>;
}

// Intent handlers
async function handleSupportIntent(event: LexV2Event): Promise<LexV2Response> {
  const { inputTranscript, sessionId } = event;
  const slots = event.interpretations[0]?.intent?.slots || {};
  
  console.log(`Processing support intent for session: ${sessionId}`);
  console.log(`Input: ${inputTranscript}`);
  console.log(`Slots: ${JSON.stringify(slots)}`);
  
  try {
    // If Bedrock agent is configured, use it for intelligent responses
    if (process.env.BEDROCK_AGENT_ID && process.env.BEDROCK_AGENT_ALIAS_ID) {
      const bedrockResponse = await invokeBedrockAgent(inputTranscript, sessionId);
      
      return {
        sessionState: {
          dialogAction: {
            type: 'Close',
            fulfillmentState: 'Fulfilled'
          },
          intent: {
            name: event.interpretations[0].intent.name,
            state: 'Fulfilled'
          }
        },
        messages: [{
          contentType: 'PlainText',
          content: bedrockResponse
        }]
      };
    }
    
    // Fallback response when Bedrock is not available
    const supportMessage = generateSupportResponse(inputTranscript, slots);
    
    return {
      sessionState: {
        dialogAction: {
          type: 'Close',
          fulfillmentState: 'Fulfilled'
        },
        intent: {
          name: event.interpretations[0].intent.name,
          state: 'Fulfilled'
        }
      },
      messages: [{
        contentType: 'PlainText',
        content: supportMessage
      }]
    };
    
  } catch (error) {
    console.error('Error processing support intent:', error);
    
    return {
      sessionState: {
        dialogAction: {
          type: 'Close',
          fulfillmentState: 'Failed'
        },
        intent: {
          name: event.interpretations[0].intent.name,
          state: 'Failed'
        }
      },
      messages: [{
        contentType: 'PlainText',
        content: 'I apologize, but I encountered an error processing your request. Please try again or contact our support team directly.'
      }]
    };
  }
}

async function handleTicketCreationIntent(event: LexV2Event): Promise<LexV2Response> {
  const slots = event.interpretations[0]?.intent?.slots || {};
  const { sessionId } = event;
  
  console.log(`Processing ticket creation for session: ${sessionId}`);
  console.log(`Slots: ${JSON.stringify(slots)}`);
  
  // Extract slot values
  const email = slots.email?.value?.interpretedValue;
  const subject = slots.subject?.value?.interpretedValue;
  const description = slots.description?.value?.interpretedValue;
  const priority = slots.priority?.value?.interpretedValue || 'normal';
  
  // Validate required slots
  if (!email || !subject || !description) {
    const missingSlots = [];
    if (!email) missingSlots.push('email');
    if (!subject) missingSlots.push('subject');
    if (!description) missingSlots.push('description');
    
    return {
      sessionState: {
        dialogAction: {
          type: 'ElicitSlot',
          slotToElicit: missingSlots[0]
        },
        intent: {
          name: event.interpretations[0].intent.name,
          state: 'InProgress',
          slots: slots
        }
      },
      messages: [{
        contentType: 'PlainText',
        content: `I need your ${missingSlots.join(', ')} to create a support ticket. Please provide this information.`
      }]
    };
  }
  
  try {
    // In a real implementation, this would call the Zendesk Lambda function
    // For now, we'll simulate ticket creation
    const ticketId = `TKT-${Date.now()}`;
    
    console.log(`Simulated ticket creation - ID: ${ticketId}`);
    
    return {
      sessionState: {
        dialogAction: {
          type: 'Close',
          fulfillmentState: 'Fulfilled'
        },
        intent: {
          name: event.interpretations[0].intent.name,
          state: 'Fulfilled'
        }
      },
      messages: [{
        contentType: 'PlainText',
        content: `Great! I've created support ticket ${ticketId} for you. Our team will review your request and get back to you shortly. You should receive a confirmation email at ${email}.`
      }]
    };
    
  } catch (error) {
    console.error('Error creating ticket:', error);
    
    return {
      sessionState: {
        dialogAction: {
          type: 'Close',
          fulfillmentState: 'Failed'
        },
        intent: {
          name: event.interpretations[0].intent.name,
          state: 'Failed'
        }
      },
      messages: [{
        contentType: 'PlainText',
        content: 'I apologize, but I encountered an error creating your support ticket. Please try again or contact our support team directly.'
      }]
    };
  }
}

async function invokeBedrockAgent(inputText: string, sessionId: string): Promise<string> {
  const params: InvokeAgentCommandInput = {
    agentId: process.env.BEDROCK_AGENT_ID!,
    agentAliasId: process.env.BEDROCK_AGENT_ALIAS_ID!,
    sessionId: sessionId,
    inputText: inputText
  };
  
  try {
    const command = new InvokeAgentCommand(params);
    const response = await bedrockClient.send(command);
    
    // Process streaming response if available
    if (response.completion) {
      const chunks: string[] = [];
      
      for await (const chunk of response.completion) {
        if (chunk.chunk?.bytes) {
          const text = new TextDecoder().decode(chunk.chunk.bytes);
          chunks.push(text);
        }
      }
      
      return chunks.join('');
    }
    
    return 'I apologize, but I didn\'t receive a proper response. Please try rephrasing your question.';
    
  } catch (error) {
    console.error('Error invoking Bedrock agent:', error);
    throw new Error('Failed to get response from AI agent');
  }
}

function generateSupportResponse(inputText: string, slots: Record<string, any>): string {
  // Simple rule-based responses for common support topics
  const lowerInput = inputText.toLowerCase();
  
  if (lowerInput.includes('password') || lowerInput.includes('login')) {
    return 'For password and login issues, please visit our account recovery page or contact our technical support team. They can help you reset your credentials securely.';
  }
  
  if (lowerInput.includes('billing') || lowerInput.includes('payment')) {
    return 'For billing and payment questions, please check your account dashboard or contact our billing department. They can provide detailed information about your account status and payment history.';
  }
  
  if (lowerInput.includes('mule') || lowerInput.includes('integration')) {
    return 'For MuleSoft integration support, our technical team can help with configuration, troubleshooting, and best practices. Would you like me to create a support ticket for you?';
  }
  
  if (lowerInput.includes('error') || lowerInput.includes('bug')) {
    return 'I understand you\'re experiencing an issue. To provide the best assistance, I\'ll need some details about the error. Would you like me to help you create a support ticket with this information?';
  }
  
  // Default response
  return 'I\'m here to help with your support needs. I can assist with common questions or help you create a support ticket for more complex issues. What specific help do you need today?';
}

export const handler: Handler = async (event: LexV2Event, context: Context): Promise<LexV2Response> => {
  console.log('Received Lex V2 event:', JSON.stringify(event, null, 2));
  console.log('Context:', JSON.stringify(context, null, 2));
  
  try {
    const intentName = event.interpretations[0]?.intent?.name;
    
    if (!intentName) {
      throw new Error('No intent found in event');
    }
    
    // Route to appropriate intent handler
    switch (intentName) {
      case 'SupportIntent':
      case 'GetHelp':
      case 'GeneralSupport':
        return await handleSupportIntent(event);
        
      case 'CreateTicketIntent':
      case 'CreateSupportTicket':
        return await handleTicketCreationIntent(event);
        
      default:
        console.log(`Unhandled intent: ${intentName}`);
        return {
          sessionState: {
            dialogAction: {
              type: 'Close',
              fulfillmentState: 'Fulfilled'
            },
            intent: {
              name: intentName,
              state: 'Fulfilled'
            }
          },
          messages: [{
            contentType: 'PlainText',
            content: 'I\'m not sure how to handle that request, but I\'m here to help with your support needs. You can ask me questions or request to create a support ticket.'
          }]
        };
    }
    
  } catch (error) {
    console.error('Error in Lex fulfillment handler:', error);
    
    return {
      sessionState: {
        dialogAction: {
          type: 'Close',
          fulfillmentState: 'Failed'
        },
        intent: {
          name: event.interpretations[0]?.intent?.name || 'Unknown',
          state: 'Failed'
        }
      },
      messages: [{
        contentType: 'PlainText',
        content: 'I apologize, but I encountered an unexpected error. Please try again or contact our support team directly.'
      }]
    };
  }
};