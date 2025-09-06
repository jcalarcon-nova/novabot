(function() {
  'use strict';
  
  // Configuration
  const CONFIG = {
    API_ENDPOINT: window.NOVABOT_API_ENDPOINT || 'https://api-novabot.dev.nova-aicoe.com/invoke-agent',
    API_KEY: window.NOVABOT_API_KEY || null,
    WIDGET_TITLE: window.NOVABOT_TITLE || 'NovaBot Support',
    ENABLE_ANALYTICS: window.NOVABOT_ANALYTICS || false,
    MAX_RETRIES: 3,
    RETRY_DELAY: 1000,
    SESSION_TIMEOUT: 30 * 60 * 1000, // 30 minutes
    TYPING_DELAY: 1000
  };
  
  class NovaBotWidget {
    constructor() {
      this.isOpen = false;
      this.messages = [];
      this.sessionId = null;
      this.isProcessing = false;
      this.retryCount = 0;
      this.currentMessageId = 0;
      this.sessionTimeout = null;
      
      this.init();
    }
    
    init() {
      this.createWidget();
      this.attachEventListeners();
      this.startSession();
      this.loadCSS();
      
      // Auto-open widget if configured
      if (window.NOVABOT_AUTO_OPEN) {
        setTimeout(() => this.openWidget(), 1000);
      }
    }
    
    loadCSS() {
      // Check if CSS is already loaded
      if (document.getElementById('novabot-styles')) return;
      
      const link = document.createElement('link');
      link.id = 'novabot-styles';
      link.rel = 'stylesheet';
      link.href = window.NOVABOT_CSS_URL || 'widget.css';
      document.head.appendChild(link);
    }
    
    createWidget() {
      // Remove existing widget if any
      const existing = document.getElementById('novabot-widget');
      if (existing) existing.remove();
      
      // Create widget HTML
      const widgetHTML = `
        <div id="novabot-widget" class="novabot-widget">
          <!-- Chat Panel -->
          <div id="novabot-chat-panel" class="novabot-chat-panel">
            <!-- Header -->
            <div class="novabot-chat-header">
              <h3>${CONFIG.WIDGET_TITLE}</h3>
              <button id="novabot-close-btn" class="novabot-close-button" title="Close chat">
                <svg viewBox="0 0 24 24" fill="currentColor">
                  <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/>
                </svg>
              </button>
            </div>
            
            <!-- Messages Container -->
            <div id="novabot-messages" class="novabot-chat-messages">
              <!-- Welcome message -->
            </div>
            
            <!-- Input Area -->
            <div class="novabot-chat-input">
              <input 
                type="text" 
                id="novabot-input" 
                class="novabot-input-field"
                placeholder="Type your message..."
                maxlength="2000"
              />
              <button id="novabot-send-btn" class="novabot-send-button" title="Send message">
                <svg viewBox="0 0 24 24" fill="currentColor" width="16" height="16">
                  <path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/>
                </svg>
              </button>
            </div>
          </div>
          
          <!-- Chat Button -->
          <button id="novabot-chat-btn" class="novabot-chat-button" title="Open NovaBot Support">
            <svg viewBox="0 0 24 24" fill="currentColor">
              <path d="M20 2H4c-1.1 0-1.99.9-1.99 2L2 22l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-2 12H6v-2h12v2zm0-3H6V9h12v2zm0-3H6V6h12v2z"/>
            </svg>
          </button>
        </div>
      `;
      
      // Insert widget into page
      document.body.insertAdjacentHTML('beforeend', widgetHTML);
      
      // Cache DOM elements
      this.elements = {
        widget: document.getElementById('novabot-widget'),
        chatPanel: document.getElementById('novabot-chat-panel'),
        chatButton: document.getElementById('novabot-chat-btn'),
        closeButton: document.getElementById('novabot-close-btn'),
        messages: document.getElementById('novabot-messages'),
        input: document.getElementById('novabot-input'),
        sendButton: document.getElementById('novabot-send-btn')
      };
      
      // Add welcome message
      this.addWelcomeMessage();
    }
    
    attachEventListeners() {
      // Chat button
      this.elements.chatButton.addEventListener('click', () => this.toggleWidget());
      
      // Close button
      this.elements.closeButton.addEventListener('click', () => this.closeWidget());
      
      // Send button
      this.elements.sendButton.addEventListener('click', () => this.sendMessage());
      
      // Input field
      this.elements.input.addEventListener('keypress', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault();
          this.sendMessage();
        }
      });
      
      // Input field focus/blur for mobile
      this.elements.input.addEventListener('focus', () => {
        if (window.innerWidth <= 480) {
          this.elements.chatPanel.style.height = '60vh';
        }
      });
      
      this.elements.input.addEventListener('blur', () => {
        if (window.innerWidth <= 480) {
          this.elements.chatPanel.style.height = '80vh';
        }
      });
      
      // Close widget when clicking outside on mobile
      document.addEventListener('click', (e) => {
        if (window.innerWidth <= 480 && this.isOpen && 
            !this.elements.widget.contains(e.target)) {
          this.closeWidget();
        }
      });
      
      // Handle page visibility changes
      document.addEventListener('visibilitychange', () => {
        if (document.hidden) {
          this.pauseSession();
        } else {
          this.resumeSession();
        }
      });
    }
    
    startSession() {
      this.sessionId = this.generateSessionId();
      this.resetSessionTimeout();
      console.log('NovaBot session started:', this.sessionId);
    }
    
    generateSessionId() {
      const timestamp = Date.now();
      const random = Math.random().toString(36).substring(2, 15);
      return `novabot_${timestamp}_${random}`;
    }
    
    resetSessionTimeout() {
      if (this.sessionTimeout) {
        clearTimeout(this.sessionTimeout);
      }
      
      this.sessionTimeout = setTimeout(() => {
        this.addSystemMessage('Session expired due to inactivity. Click here to start a new session.', true);
        this.sessionId = null;
      }, CONFIG.SESSION_TIMEOUT);
    }
    
    pauseSession() {
      if (this.sessionTimeout) {
        clearTimeout(this.sessionTimeout);
      }
    }
    
    resumeSession() {
      if (this.sessionId) {
        this.resetSessionTimeout();
      }
    }
    
    toggleWidget() {
      if (this.isOpen) {
        this.closeWidget();
      } else {
        this.openWidget();
      }
    }
    
    openWidget() {
      this.isOpen = true;
      this.elements.chatPanel.classList.add('open');
      this.elements.chatButton.style.display = 'none';
      this.elements.input.focus();
      
      // Analytics
      this.trackEvent('widget_opened');
    }
    
    closeWidget() {
      this.isOpen = false;
      this.elements.chatPanel.classList.remove('open');
      this.elements.chatButton.style.display = 'flex';
      
      // Analytics
      this.trackEvent('widget_closed');
    }
    
    addWelcomeMessage() {
      const welcomeText = `
        👋 Hi! I'm NovaBot, your AI support assistant. 
        
        I can help you with:
        • Technical questions about MuleSoft and APIs
        • Troubleshooting integration issues
        • Finding documentation and best practices
        • Creating support tickets for complex issues
        
        What can I help you with today?
      `;
      
      this.addMessage('agent', welcomeText.trim(), {
        showActions: true,
        timestamp: new Date()
      });
    }
    
    async sendMessage() {
      const text = this.elements.input.value.trim();
      if (!text || this.isProcessing) return;
      
      // Check session
      if (!this.sessionId) {
        this.startSession();
      }
      
      // Add user message
      this.addMessage('user', text, { timestamp: new Date() });
      
      // Clear input
      this.elements.input.value = '';
      
      // Show typing indicator
      this.showTypingIndicator();
      
      // Reset session timeout
      this.resetSessionTimeout();
      
      // Send to API
      await this.callAPI(text);
    }
    
    async callAPI(inputText) {
      this.isProcessing = true;
      this.elements.sendButton.disabled = true;
      
      const requestData = {
        sessionId: this.sessionId,
        inputText: inputText,
        sessionAttributes: {
          timestamp: new Date().toISOString(),
          userAgent: navigator.userAgent,
          referrer: document.referrer || window.location.href
        },
        enableStreaming: true // Enable streaming for better UX
      };
      
      const headers = {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream, application/json'
      };
      
      if (CONFIG.API_KEY) {
        headers['X-API-Key'] = CONFIG.API_KEY;
      }
      
      try {
        console.log('Calling NovaBot API:', CONFIG.API_ENDPOINT);
        
        const response = await fetch(CONFIG.API_ENDPOINT, {
          method: 'POST',
          headers: headers,
          body: JSON.stringify(requestData)
        });
        
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        // Check if response is streaming (Server-Sent Events)
        const contentType = response.headers.get('content-type') || '';
        if (contentType.includes('text/event-stream')) {
          await this.handleStreamingResponse(response);
        } else {
          // Fallback to regular JSON response
          const data = await response.json();
          this.hideTypingIndicator();
          this.processAPIResponse(data);
        }
        
        // Reset retry count
        this.retryCount = 0;
        
        // Analytics
        this.trackEvent('message_sent', {
          input_length: inputText.length,
          streaming: contentType.includes('text/event-stream')
        });
        
      } catch (error) {
        console.error('API call failed:', error);
        this.hideTypingIndicator();
        this.handleAPIError(error, inputText);
      } finally {
        this.isProcessing = false;
        this.elements.sendButton.disabled = false;
      }
    }
    
    async handleStreamingResponse(response) {
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      
      // Hide typing indicator and prepare for streaming
      this.hideTypingIndicator();
      
      // Create message element for streaming
      const messageId = this.addMessage('agent', '', {
        timestamp: new Date(),
        streaming: false // Don't use typewriter effect for real streaming
      });
      
      const messageElement = this.elements.messages.querySelector(`[data-message-id="${messageId}"] .novabot-message-content`);
      let buffer = '';
      let fullText = '';
      let citations = [];
      let sessionId = null;
      
      try {
        while (true) {
          const { done, value } = await reader.read();
          
          if (done) break;
          
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split('\n');
          
          // Keep the last incomplete line in buffer
          buffer = lines.pop() || '';
          
          for (const line of lines) {
            if (line.trim() === '') continue;
            
            if (line.startsWith('data: ')) {
              try {
                const jsonData = JSON.parse(line.slice(6));
                
                if (jsonData.type === 'token') {
                  fullText += jsonData.content;
                  messageElement.innerHTML = this.formatMessageText(fullText);
                  this.scrollToBottom();
                } else if (jsonData.type === 'metadata') {
                  if (jsonData.citations) citations = jsonData.citations;
                  if (jsonData.sessionId) sessionId = jsonData.sessionId;
                } else if (jsonData.type === 'complete') {
                  // Streaming complete, add final metadata
                  if (citations.length > 0) {
                    this.addCitationsToMessage(messageId, citations);
                  }
                  if (sessionId && sessionId !== this.sessionId) {
                    this.sessionId = sessionId;
                  }
                }
              } catch (e) {
                console.warn('Failed to parse streaming data:', line, e);
              }
            }
          }
        }
      } catch (error) {
        console.error('Streaming error:', error);
        if (fullText === '') {
          messageElement.innerHTML = this.formatMessageText("I apologize, there was an issue receiving the response. Please try again.");
        }
      }
      
      // Ensure we have some response
      if (fullText === '') {
        messageElement.innerHTML = this.formatMessageText("I apologize, but I didn't receive a proper response. Could you please try rephrasing your question?");
      }
      
      this.scrollToBottom();
    }
    
    processAPIResponse(data) {
      const { completion, citations, traces, sessionId } = data;
      
      // Update session ID if provided
      if (sessionId && sessionId !== this.sessionId) {
        this.sessionId = sessionId;
      }
      
      if (completion) {
        // Add agent message with typewriter effect for non-streaming responses
        this.addMessage('agent', completion, {
          citations: citations,
          traces: traces,
          timestamp: new Date(),
          streaming: true
        });
      } else {
        this.addMessage('agent', "I apologize, but I didn't receive a proper response. Could you please try rephrasing your question?", {
          timestamp: new Date()
        });
      }
    }
    
    handleAPIError(error, originalInput) {
      this.retryCount++;
      
      if (this.retryCount <= CONFIG.MAX_RETRIES) {
        console.log(`Retrying API call (${this.retryCount}/${CONFIG.MAX_RETRIES})...`);
        
        setTimeout(() => {
          this.callAPI(originalInput);
        }, CONFIG.RETRY_DELAY * this.retryCount);
        
        return;
      }
      
      // Max retries exceeded
      let errorMessage = "I'm experiencing technical difficulties right now. ";
      
      if (error.message.includes('404')) {
        errorMessage += "The support service is not available.";
      } else if (error.message.includes('429')) {
        errorMessage += "Too many requests. Please wait a moment before trying again.";
      } else if (error.message.includes('500')) {
        errorMessage += "There's a server issue. Please try again in a few minutes.";
      } else if (error.message.includes('CORS')) {
        errorMessage += "There's a connection configuration issue. Please try refreshing the page.";
      } else if (error.message.includes('NetworkError') || error.message.includes('Failed to fetch')) {
        errorMessage += "Please check your internet connection and try again.";
      } else {
        errorMessage += "Please check your connection and try again.";
      }
      
      errorMessage += " Would you like me to help you create a support ticket instead?";
      
      this.addMessage('agent', errorMessage, {
        timestamp: new Date(),
        showActions: true,
        isError: true
      });
      
      // Reset retry count
      this.retryCount = 0;
      
      // Analytics
      this.trackEvent('api_error', {
        error_message: error.message,
        retry_count: this.retryCount,
        endpoint: CONFIG.API_ENDPOINT
      });
    }
    
    addMessage(sender, text, options = {}) {
      const {
        citations = [],
        traces = [],
        timestamp = new Date(),
        showActions = false,
        streaming = false,
        isError = false
      } = options;
      
      const messageId = ++this.currentMessageId;
      const message = {
        id: messageId,
        sender,
        text,
        timestamp,
        citations,
        traces,
        isError
      };
      
      this.messages.push(message);
      
      // Create message element
      const messageEl = this.createMessageElement(message, showActions);
      this.elements.messages.appendChild(messageEl);
      
      // Scroll to bottom
      this.scrollToBottom();
      
      // Add streaming effect for agent messages
      if (streaming && sender === 'agent') {
        this.animateMessageText(messageEl.querySelector('.novabot-message-content'), text);
      }
      
      return messageId;
    }
    
    createMessageElement(message, showActions = false) {
      const { sender, text, timestamp, citations, isError } = message;
      
      const messageEl = document.createElement('div');
      messageEl.className = `novabot-message ${sender} novabot-fade-in`;
      messageEl.setAttribute('data-message-id', message.id);
      
      const avatar = sender === 'user' ? 'U' : '🤖';
      const timeStr = timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      
      // Citations/Sources section removed as per issue #19 requirements
      let citationsHTML = '';
      
      let actionsHTML = '';
      if (showActions && sender === 'agent') {
        actionsHTML = `
          <div class="novabot-actions">
            <button class="novabot-create-ticket-button" onclick="window.novaBotWidget.createTicket()">
              Create Support Ticket
            </button>
          </div>
        `;
      }
      
      messageEl.innerHTML = `
        <div class="novabot-message-avatar">${avatar}</div>
        <div class="novabot-message-wrapper">
          <div class="novabot-message-content ${isError ? 'error' : ''}">${this.formatMessageText(text)}</div>
          ${citationsHTML}
          ${actionsHTML}
          <div class="novabot-message-time">${timeStr}</div>
        </div>
      `;
      
      return messageEl;
    }
    
    formatMessageText(text) {
      // Convert line breaks to HTML with proper spacing
      let formatted = text.replace(/\n\s*\n/g, '<br><br>').replace(/\n/g, '<br>');
      
      // Convert URLs to links with better styling
      const urlRegex = /(https?:\/\/[^\s]+)/g;
      formatted = formatted.replace(urlRegex, '<a href="$1" target="_blank" rel="noopener" class="novabot-link">$1</a>');
      
      // Convert email addresses to mailto links
      const emailRegex = /([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/g;
      formatted = formatted.replace(emailRegex, '<a href="mailto:$1" class="novabot-link">$1</a>');
      
      // Format code blocks (basic markdown-like syntax)
      formatted = formatted.replace(/`([^`]+)`/g, '<code class="novabot-code">$1</code>');
      
      // Format bold text
      formatted = formatted.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
      
      // Format bullet points
      formatted = formatted.replace(/^[•\-\*]\s+(.+)$/gm, '<span class="novabot-bullet">• $1</span>');
      
      return formatted;
    }
    
    animateMessageText(element, text) {
      element.innerHTML = '';
      let currentIndex = 0;
      
      const typeWriter = () => {
        if (currentIndex < text.length) {
          element.innerHTML = this.formatMessageText(text.substring(0, currentIndex + 1));
          currentIndex++;
          this.scrollToBottom();
          setTimeout(typeWriter, 30); // Adjust speed here
        }
      };
      
      typeWriter();
    }
    
    showTypingIndicator() {
      const typingEl = document.createElement('div');
      typingEl.className = 'novabot-message agent novabot-typing-indicator';
      typingEl.innerHTML = `
        <div class="novabot-message-avatar">🤖</div>
        <div class="novabot-typing">
          <span>NovaBot is typing</span>
          <div class="novabot-typing-dots">
            <div class="novabot-typing-dot"></div>
            <div class="novabot-typing-dot"></div>
            <div class="novabot-typing-dot"></div>
          </div>
        </div>
      `;
      
      this.elements.messages.appendChild(typingEl);
      this.scrollToBottom();
    }
    
    hideTypingIndicator() {
      const typingEl = this.elements.messages.querySelector('.novabot-typing-indicator');
      if (typingEl) {
        typingEl.remove();
      }
    }
    
    addSystemMessage(text, clickable = false) {
      const messageEl = document.createElement('div');
      messageEl.className = 'novabot-message system';
      messageEl.innerHTML = `
        <div class="novabot-message-content">
          ${clickable ? `<a href="#" onclick="window.novaBotWidget.startSession(); return false;">${text}</a>` : text}
        </div>
      `;
      
      this.elements.messages.appendChild(messageEl);
      this.scrollToBottom();
    }
    
    scrollToBottom() {
      requestAnimationFrame(() => {
        this.elements.messages.scrollTop = this.elements.messages.scrollHeight;
      });
    }
    
    // Action handlers
    createTicket() {
      const ticketMessage = "🎫 **I'll help you create a support ticket!**\n\n" +
        "Please provide the following information:\n\n" +
        "• **Email address** - Where we should contact you\n" +
        "• **Subject** - Brief summary of your issue\n" +
        "• **Description** - Detailed explanation of the problem\n" +
        "• **Priority** - Low, Medium, High, or Critical\n" +
        "• **Version info** - Any relevant software versions\n\n" +
        "Once you provide this information, I'll create the ticket for you right away! 🚀";
      
      this.addMessage('agent', ticketMessage, { timestamp: new Date(), streaming: true });
    }
    
    showExamples() {
      const examplesMessage = "Here are some example questions you can ask:\n\n" +
        "• \"How do I configure MuleSoft HTTP connector?\"\n" +
        "• \"I'm getting a timeout error in my API integration\"\n" +
        "• \"What's the best practice for error handling in Mule flows?\"\n" +
        "• \"Create a support ticket for connection issues\"\n" +
        "• \"Show me documentation for DataWeave transformations\"";
      
      this.addMessage('agent', examplesMessage, { timestamp: new Date() });
    }
    
    // Analytics
    trackEvent(eventName, data = {}) {
      if (!CONFIG.ENABLE_ANALYTICS) return;
      
      const eventData = {
        event: eventName,
        sessionId: this.sessionId,
        timestamp: new Date().toISOString(),
        url: window.location.href,
        ...data
      };
      
      // Send to analytics service
      if (window.gtag) {
        window.gtag('event', eventName, data);
      }
      
      if (window.analytics) {
        window.analytics.track(eventName, eventData);
      }
      
      console.log('NovaBot Analytics:', eventData);
    }
    
    addCitationsToMessage(messageId, citations) {
      // Citations/Sources section removed as per issue #19 requirements
      // This method is kept for API compatibility but does nothing
      return;
    }
    
    // Public API methods
    sendUserMessage(message) {
      this.elements.input.value = message;
      this.sendMessage();
    }
    
    clearChat() {
      this.messages = [];
      this.elements.messages.innerHTML = '';
      this.addWelcomeMessage();
    }
    
    setAPIEndpoint(endpoint) {
      CONFIG.API_ENDPOINT = endpoint;
    }
    
    // Test streaming capability
    async testStreaming() {
      console.log('Testing streaming capability...');
      const testMessage = 'Test streaming response';
      this.elements.input.value = testMessage;
      await this.sendMessage();
    }
    
    // Get current API endpoint
    getAPIEndpoint() {
      return CONFIG.API_ENDPOINT;
    }
    
    destroy() {
      if (this.elements.widget) {
        this.elements.widget.remove();
      }
      if (this.sessionTimeout) {
        clearTimeout(this.sessionTimeout);
      }
    }
  }
  
  // Initialize widget when DOM is ready
  function initializeWidget() {
    // Check if widget is already initialized
    if (window.novaBotWidget) {
      console.warn('NovaBot widget already initialized');
      return;
    }
    
    // Create widget instance
    window.novaBotWidget = new NovaBotWidget();
    
    // Expose public API
    window.NovaBot = {
      open: () => window.novaBotWidget.openWidget(),
      close: () => window.novaBotWidget.closeWidget(),
      sendMessage: (msg) => window.novaBotWidget.sendUserMessage(msg),
      clearChat: () => window.novaBotWidget.clearChat(),
      setEndpoint: (endpoint) => window.novaBotWidget.setAPIEndpoint(endpoint),
      getEndpoint: () => window.novaBotWidget.getAPIEndpoint(),
      testStreaming: () => window.novaBotWidget.testStreaming(),
      destroy: () => window.novaBotWidget.destroy()
    };
    
    console.log('NovaBot widget initialized successfully');
  }
  
  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeWidget);
  } else {
    initializeWidget();
  }
  
})();