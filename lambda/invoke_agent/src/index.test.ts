import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { BedrockAgentRuntimeClient, InvokeAgentCommand } from '@aws-sdk/client-bedrock-agent-runtime';
import { handler } from './index';

// Mock the Bedrock client
jest.mock('@aws-sdk/client-bedrock-agent-runtime');
const MockedBedrockClient = BedrockAgentRuntimeClient as jest.MockedClass<typeof BedrockAgentRuntimeClient>;
const mockSend = jest.fn();

describe('invoke_agent Lambda Handler', () => {
  beforeEach(() => {
    jest.clearAllMocks();

    // Set required environment variables
    process.env.BEDROCK_AGENT_ID = 'test-agent-id';
    process.env.BEDROCK_AGENT_ALIAS_ID = 'test-alias-id';
    process.env.AWS_REGION = 'us-east-1';

    // Mock BedrockClient
    MockedBedrockClient.mockImplementation(() => ({
      send: mockSend
    } as any));
  });

  afterEach(() => {
    // Clean up environment variables
    delete process.env.BEDROCK_AGENT_ID;
    delete process.env.BEDROCK_AGENT_ALIAS_ID;
    delete process.env.AWS_REGION;
  });

  const createMockEvent = (body: any): APIGatewayProxyEvent => ({
    body: JSON.stringify(body),
    headers: {},
    multiValueHeaders: {},
    httpMethod: 'POST',
    isBase64Encoded: false,
    path: '/invoke',
    pathParameters: null,
    queryStringParameters: null,
    multiValueQueryStringParameters: null,
    stageVariables: null,
    requestContext: {
      accountId: '123456789012',
      apiId: 'test-api',
      protocol: 'HTTP/1.1',
      httpMethod: 'POST',
      path: '/invoke',
      stage: 'test',
      requestId: 'test-request',
      requestTime: '01/Jan/2023:00:00:00 +0000',
      requestTimeEpoch: 1672531200000,
      authorizer: null,
      identity: {
        cognitoIdentityPoolId: null,
        accountId: null,
        cognitoIdentityId: null,
        caller: null,
        sourceIp: '127.0.0.1',
        principalOrgId: null,
        accessKey: null,
        cognitoAuthenticationType: null,
        cognitoAuthenticationProvider: null,
        userArn: null,
        userAgent: 'test-agent',
        user: null,
        apiKey: null,
        apiKeyId: null,
        clientCert: null
      },
      resourceId: 'test-resource',
      resourcePath: '/invoke'
    },
    resource: '/invoke'
  });

  describe('Request Validation', () => {
    it('should return 400 for invalid JSON body', async () => {
      const event: APIGatewayProxyEvent = {
        ...createMockEvent({}),
        body: 'invalid-json'
      };

      const result = await (handler as any)(event) as APIGatewayProxyResult;

      expect(result.statusCode).toBe(400);
      expect(JSON.parse(result.body)).toMatchObject({
        error: 'Invalid JSON in request body'
      });
    });

    it('should return 400 for missing inputText', async () => {
      const event = createMockEvent({
        sessionId: 'test-session'
      });

      const result = await (handler as any)(event) as APIGatewayProxyResult;

      expect(result.statusCode).toBe(400);
      expect(JSON.parse(result.body)).toMatchObject({
        error: 'Invalid request format. Required: inputText (string)'
      });
    });

    it('should return 400 for empty inputText', async () => {
      const event = createMockEvent({
        inputText: ''
      });

      const result = await (handler as any)(event) as APIGatewayProxyResult;

      expect(result.statusCode).toBe(400);
      expect(JSON.parse(result.body)).toMatchObject({
        error: 'Invalid request format. Required: inputText (string)'
      });
    });

    it('should accept valid request without sessionId', async () => {
      const mockResponse = {
        sessionId: 'generated-session-id',
        completion: mockAsyncIterable([
          { chunk: { bytes: new TextEncoder().encode('Hello, world!') } }
        ])
      };

      mockSend.mockResolvedValue(mockResponse);

      const event = createMockEvent({
        inputText: 'Hello'
      });

      const result = await (handler as any)(event) as APIGatewayProxyResult;

      expect(result.statusCode).toBe(200);
      expect(mockSend).toHaveBeenCalledWith(expect.any(InvokeAgentCommand));
    });
  });

  describe('Session ID Generation', () => {
    it('should generate sessionId when not provided', async () => {
      const mockResponse = {
        sessionId: 'generated-session-id',
        completion: mockAsyncIterable([
          { chunk: { bytes: new TextEncoder().encode('Test response') } }
        ])
      };

      mockSend.mockResolvedValue(mockResponse);

      const event = createMockEvent({
        inputText: 'Test input'
      });

      const result = await (handler as any)(event) as APIGatewayProxyResult;
      
      expect(result.statusCode).toBe(200);
      
      const commandCall = mockSend.mock.calls[0][0];
      expect(commandCall.input.sessionId).toMatch(/^session_\d+_[a-z0-9]+$/);
    });

    it('should use provided sessionId', async () => {
      const mockResponse = {
        sessionId: 'provided-session-id',
        completion: mockAsyncIterable([
          { chunk: { bytes: new TextEncoder().encode('Test response') } }
        ])
      };

      mockSend.mockResolvedValue(mockResponse);

      const event = createMockEvent({
        sessionId: 'provided-session-id',
        inputText: 'Test input'
      });

      const result = await (handler as any)(event) as APIGatewayProxyResult;
      
      expect(result.statusCode).toBe(200);
      
      const commandCall = mockSend.mock.calls[0][0];
      expect(commandCall.input.sessionId).toBe('provided-session-id');
    });
  });

  describe('Bedrock Agent Integration', () => {
    it('should process streaming response correctly', async () => {
      const testText1 = 'Hello, ';
      const testText2 = 'world!';
      
      const mockResponse = {
        sessionId: 'test-session',
        completion: mockAsyncIterable([
          { chunk: { bytes: new TextEncoder().encode(testText1) } },
          { chunk: { bytes: new TextEncoder().encode(testText2) } }
        ])
      };

      mockSend.mockResolvedValue(mockResponse);

      const event = createMockEvent({
        sessionId: 'test-session',
        inputText: 'Hello'
      });

      const result = await (handler as any)(event) as APIGatewayProxyResult;

      expect(result.statusCode).toBe(200);
      const response = JSON.parse(result.body);
      expect(response.completion).toBe(testText1 + testText2);
      expect(response.sessionId).toBe('test-session');
    });

    it('should handle traces in response', async () => {
      const mockTrace = { traceId: 'test-trace-123' };
      
      const mockResponse = {
        sessionId: 'test-session',
        completion: mockAsyncIterable([
          { 
            chunk: { bytes: new TextEncoder().encode('Response text') },
            trace: mockTrace
          }
        ])
      };

      mockSend.mockResolvedValue(mockResponse);

      const event = createMockEvent({
        sessionId: 'test-session',
        inputText: 'Test with trace',
        enableTrace: true
      });

      const result = await (handler as any)(event) as APIGatewayProxyResult;

      expect(result.statusCode).toBe(200);
      const response = JSON.parse(result.body);
      expect(response.traces).toEqual([mockTrace]);
    });

    it('should handle citations in response', async () => {
      const mockCitations = [
        { source: 'doc1.pdf', excerpt: 'Test citation' }
      ];
      
      const mockResponse = {
        sessionId: 'test-session',
        completion: mockAsyncIterable([
          { 
            chunk: { 
              bytes: new TextEncoder().encode('Response with citation'),
              attribution: { citations: mockCitations }
            }
          }
        ])
      };

      mockSend.mockResolvedValue(mockResponse);

      const event = createMockEvent({
        sessionId: 'test-session',
        inputText: 'Test with citation'
      });

      const result = await (handler as any)(event) as APIGatewayProxyResult;

      expect(result.statusCode).toBe(200);
      const response = JSON.parse(result.body);
      expect(response.citations).toEqual(mockCitations);
    });

    it('should handle empty completion stream', async () => {
      const mockResponse = {
        sessionId: 'test-session',
        completion: undefined
      };

      mockSend.mockResolvedValue(mockResponse);

      const event = createMockEvent({
        sessionId: 'test-session',
        inputText: 'Test input'
      });

      const result = await (handler as any)(event) as APIGatewayProxyResult;

      expect(result.statusCode).toBe(500);
      expect(JSON.parse(result.body)).toMatchObject({
        error: 'No completion stream received from Bedrock agent'
      });
    });
  });

  describe('Error Handling', () => {
    it('should handle Bedrock client errors', async () => {
      const error = new Error('Bedrock service unavailable');
      mockSend.mockRejectedValue(error);

      const event = createMockEvent({
        sessionId: 'test-session',
        inputText: 'Test input'
      });

      const result = await (handler as any)(event) as APIGatewayProxyResult;

      expect(result.statusCode).toBe(500);
      expect(JSON.parse(result.body)).toMatchObject({
        error: 'Internal server error'
      });
    });

    it('should handle streaming errors', async () => {
      const mockResponse = {
        sessionId: 'test-session',
        completion: mockAsyncIterableWithError('Stream processing failed')
      };

      mockSend.mockResolvedValue(mockResponse);

      const event = createMockEvent({
        sessionId: 'test-session',
        inputText: 'Test input'
      });

      const result = await (handler as any)(event) as APIGatewayProxyResult;

      expect(result.statusCode).toBe(500);
      expect(JSON.parse(result.body)).toMatchObject({
        error: 'Internal server error'
      });
    });
  });

  describe('Session Attributes', () => {
    it('should pass session attributes to Bedrock', async () => {
      const mockResponse = {
        sessionId: 'test-session',
        completion: mockAsyncIterable([
          { chunk: { bytes: new TextEncoder().encode('Response') } }
        ])
      };

      mockSend.mockResolvedValue(mockResponse);

      const sessionAttributes = {
        userId: 'user123',
        department: 'sales'
      };

      const event = createMockEvent({
        sessionId: 'test-session',
        inputText: 'Test input',
        sessionAttributes
      });

      const result = await (handler as any)(event) as APIGatewayProxyResult;

      expect(result.statusCode).toBe(200);
      
      const commandCall = mockSend.mock.calls[0][0];
      expect(commandCall.input.sessionState?.sessionAttributes).toEqual(sessionAttributes);
    });
  });
});

// Helper function to create mock async iterable
function mockAsyncIterable<T>(items: T[]): AsyncIterable<T> {
  return {
    [Symbol.asyncIterator]: async function* () {
      for (const item of items) {
        yield item;
      }
    }
  };
}

// Helper function to create mock async iterable that throws error
function mockAsyncIterableWithError(errorMessage: string): AsyncIterable<any> {
  return {
    [Symbol.asyncIterator]: async function* () {
      throw new Error(errorMessage);
    }
  };
}