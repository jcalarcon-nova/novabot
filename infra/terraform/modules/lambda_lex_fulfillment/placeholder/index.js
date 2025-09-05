exports.handler = async (event) => {
  console.log('Placeholder Lex fulfillment Lambda function');
  console.log('Event:', JSON.stringify(event, null, 2));
  
  return {
    sessionState: {
      dialogAction: {
        type: 'Close',
        fulfillmentState: 'Fulfilled'
      },
      intent: {
        name: event.interpretations?.[0]?.intent?.name || 'Unknown',
        state: 'Fulfilled'
      }
    },
    messages: [{
      contentType: 'PlainText',
      content: 'This is a placeholder response. The actual Lex fulfillment function needs to be deployed.'
    }]
  };
};
