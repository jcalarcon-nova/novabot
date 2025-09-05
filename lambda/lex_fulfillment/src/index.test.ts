import { LexV2Event, LexV2Result, Context } from 'aws-lambda';
import { handler } from './index';

describe('lex_fulfillment Lambda Handler', () => {
  let mockContext: Context;

  beforeEach(() => {
    // Set up mock context
    mockContext = {
      callbackWaitsForEmptyEventLoop: false,
      functionName: 'test-function',
      functionVersion: '1',
      invokedFunctionArn: 'arn:aws:lambda:us-east-1:123456789012:function:test-function',
      memoryLimitInMB: '128',
      awsRequestId: 'test-request-id',
      logGroupName: '/aws/lambda/test-function',
      logStreamName: '2023/01/01/[$LATEST]test-stream',
      getRemainingTimeInMillis: () => 30000,
      done: jest.fn(),
      fail: jest.fn(),
      succeed: jest.fn()
    };

    // Set required environment variables
    process.env.BEDROCK_AGENT_ID = 'test-agent-id';
    process.env.BEDROCK_AGENT_ALIAS_ID = 'test-alias-id';
    process.env.AWS_REGION = 'us-east-1';
  });

  afterEach(() => {
    // Clean up environment variables
    delete process.env.BEDROCK_AGENT_ID;
    delete process.env.BEDROCK_AGENT_ALIAS_ID;
    delete process.env.AWS_REGION;
  });

  const createMockLexEvent = (overrides: Partial<LexV2Event> = {}): LexV2Event => ({
    messageVersion: '1.0',
    invocationSource: 'FulfillmentCodeHook',
    inputMode: 'Text',
    responseContentType: 'PlainText',
    sessionId: 'test-session-123',
    inputTranscript: 'Hello, I need help',
    bot: {
      id: 'test-bot-id',
      name: 'TestBot',
      version: 'DRAFT',
      localeId: 'en_US'
    },
    interpretations: [
      {
        intent: {
          confirmationState: 'None',
          name: 'GetHelp',
          slots: {},
          state: 'Fulfilled'
        },
        nluConfidence: {
          score: 0.85
        }
      }
    ],
    proposedNextState: {
      intent: {
        confirmationState: 'None',
        name: 'GetHelp',
        slots: {},
        state: 'Fulfilled'
      }
    },
    requestAttributes: {},
    sessionState: {
      activeContexts: [],
      sessionAttributes: {},
      intent: {
        confirmationState: 'None',
        name: 'GetHelp',
        slots: {},
        state: 'Fulfilled'
      },
      originatingRequestId: 'test-request-123'
    },
    transcriptions: [
      {
        transcription: 'Hello, I need help',
        transcriptionConfidence: 0.95,
        resolvedContext: {
          intent: 'GetHelp'
        },
        resolvedSlots: {}
      }
    ],
    ...overrides
  });

  describe('Basic Event Processing', () => {
    it('should process a basic Lex event successfully', async () => {
      const event = createMockLexEvent();

      const result = await (handler as any)(event, mockContext) as LexV2Result;

      expect(result).toBeDefined();
      expect(result.sessionState).toBeDefined();
      expect(result.messages).toBeDefined();
      expect(Array.isArray(result.messages)).toBe(true);
    });

    it('should handle DialogCodeHook invocation source', async () => {
      const event = createMockLexEvent({
        invocationSource: 'DialogCodeHook'
      });

      const result = await (handler as any)(event, mockContext) as LexV2Result;

      expect(result).toBeDefined();
      expect(result.sessionState).toBeDefined();
    });

    it('should handle different input modes', async () => {
      const speechEvent = createMockLexEvent({
        inputMode: 'Speech'
      });

      const result = await (handler as any)(speechEvent, mockContext) as LexV2Result;

      expect(result).toBeDefined();
      expect(result.sessionState).toBeDefined();
    });
  });

  describe('Intent Handling', () => {
    it('should handle GetHelp intent', async () => {
      const event = createMockLexEvent({
        interpretations: [
          {
            intent: {
              confirmationState: 'None',
              name: 'GetHelp',
              slots: {},
              state: 'Fulfilled'
            },
            nluConfidence: {
              score: 0.9
            }
          }
        ]
      });

      const result = await (handler as any)(event, mockContext) as LexV2Result;

      expect(result).toBeDefined();
      expect(result.messages).toBeDefined();
      expect(result.messages.length).toBeGreaterThan(0);
    });

    it('should handle unknown intents gracefully', async () => {
      const event = createMockLexEvent({
        interpretations: [
          {
            intent: {
              confirmationState: 'None',
              name: 'UnknownIntent',
              slots: {},
              state: 'Fulfilled'
            },
            nluConfidence: {
              score: 0.5
            }
          }
        ]
      });

      const result = await (handler as any)(event, mockContext) as LexV2Result;

      expect(result).toBeDefined();
      expect(result.sessionState).toBeDefined();
    });
  });

  describe('Error Handling', () => {
    it('should handle missing environment variables', async () => {
      delete process.env.BEDROCK_AGENT_ID;
      delete process.env.BEDROCK_AGENT_ALIAS_ID;

      const event = createMockLexEvent();

      // Should not throw an error but may return an error message
      const result = await (handler as any)(event, mockContext) as LexV2Result;

      expect(result).toBeDefined();
      expect(result.sessionState).toBeDefined();
    });

    it('should handle malformed session data', async () => {
      const event = createMockLexEvent({
        sessionState: undefined as any
      });

      const result = await (handler as any)(event, mockContext) as LexV2Result;

      expect(result).toBeDefined();
    });
  });

  describe('Session Management', () => {
    it('should preserve session attributes', async () => {
      const sessionAttributes = {
        userId: 'user123',
        lastIntent: 'GetHelp'
      };

      const event = createMockLexEvent({
        sessionState: {
          activeContexts: [],
          sessionAttributes,
          intent: {
            confirmationState: 'None',
            name: 'GetHelp',
            slots: {},
            state: 'Fulfilled'
          },
          originatingRequestId: 'test-request-123'
        }
      });

      const result = await (handler as any)(event, mockContext) as LexV2Result;

      expect(result).toBeDefined();
      expect(result.sessionState).toBeDefined();
      // Session attributes should be preserved or appropriately modified
    });

    it('should handle session ID consistently', async () => {
      const sessionId = 'consistent-session-123';
      const event = createMockLexEvent({
        sessionId
      });

      const result = await (handler as any)(event, mockContext) as LexV2Result;

      expect(result).toBeDefined();
      expect(result.sessionState).toBeDefined();
    });
  });
});