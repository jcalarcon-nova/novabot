import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { handler } from './index';

describe('invoke_agent Lambda Handler - Core Tests', () => {
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
    it('should handle CORS preflight request', async () => {
      const event: APIGatewayProxyEvent = {
        ...createMockEvent({}),
        httpMethod: 'OPTIONS'
      };

      const result = await (handler as any)(event) as APIGatewayProxyResult;

      expect(result.statusCode).toBe(200);
      expect(result.headers).toMatchObject({
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'OPTIONS,POST',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
      });
    });

    it('should return 400 for missing body', async () => {
      const event: APIGatewayProxyEvent = {
        ...createMockEvent({}),
        body: null
      };

      const result = await (handler as any)(event) as APIGatewayProxyResult;

      expect(result.statusCode).toBe(400);
      expect(JSON.parse(result.body)).toMatchObject({
        error: 'Request body is required'
      });
    });

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

    it('should return 500 for missing Bedrock configuration', async () => {
      // Clear environment variables to test configuration error
      delete process.env.BEDROCK_AGENT_ID;
      delete process.env.BEDROCK_AGENT_ALIAS_ID;

      const event = createMockEvent({
        inputText: 'Hello'
      });

      const result = await (handler as any)(event) as APIGatewayProxyResult;

      expect(result.statusCode).toBe(500);
      expect(JSON.parse(result.body)).toMatchObject({
        error: 'Bedrock agent configuration not found'
      });

      // Restore for other tests
      process.env.BEDROCK_AGENT_ID = 'test-agent-id';
      process.env.BEDROCK_AGENT_ALIAS_ID = 'test-alias-id';
    });
  });

  describe('Response Format', () => {
    it('should include CORS headers in all responses', async () => {
      const event = createMockEvent({});

      const result = await (handler as any)(event) as APIGatewayProxyResult;

      expect(result.headers).toMatchObject({
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'OPTIONS,POST',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Content-Type': 'application/json'
      });
    });

    it('should include timestamp in error responses', async () => {
      const event = createMockEvent({});

      const result = await (handler as any)(event) as APIGatewayProxyResult;
      const body = JSON.parse(result.body);

      expect(body).toHaveProperty('timestamp');
      expect(body.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
    });
  });
});