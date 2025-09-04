locals {
  connect_instance_alias = var.connect_instance_alias != "" ? var.connect_instance_alias : "${var.project_name}-${var.environment}"
}

# Amazon Connect Instance (conditional creation)
resource "aws_connect_instance" "novabot_instance" {
  count = var.enable_connect ? 1 : 0
  
  identity_management_type = var.connect_directory_id != "" ? "EXISTING_DIRECTORY" : "CONNECT_MANAGED"
  directory_id            = var.connect_directory_id != "" ? var.connect_directory_id : null
  inbound_calls_enabled   = var.inbound_calls_enabled
  outbound_calls_enabled  = var.outbound_calls_enabled
  instance_alias          = local.connect_instance_alias
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-connect"
  })
}

# Contact Flow Logs (if enabled)
resource "aws_connect_contact_flow_module" "default_module" {
  count = var.enable_connect && var.contact_flow_logs_enabled ? 1 : 0
  
  instance_id = aws_connect_instance.novabot_instance[0].id
  name        = "NovaBot Default Module"
  description = "Default contact flow module for NovaBot"
  
  content = jsonencode({
    Version = "2019-10-30"
    StartAction = "StartFlow"
    Actions = [
      {
        Identifier = "StartFlow"
        Type       = "MessageParticipant"
        Parameters = {
          Text = "Welcome to NovaBot Support! Connecting you to our AI assistant..."
        }
        Transitions = {
          NextAction = "InvokeNovaBot"
        }
      },
      {
        Identifier = "InvokeNovaBot"
        Type       = "InvokeLambdaFunction"
        Parameters = {
          LambdaFunctionARN = var.lex_lambda_arn
          InvocationTimeLimitSeconds = 30
        }
        Transitions = {
          NextAction = "EndFlow"
        }
      },
      {
        Identifier = "EndFlow"
        Type       = "DisconnectParticipant"
        Parameters = {}
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-default-module"
  })
}

# Hours of Operation
resource "aws_connect_hours_of_operation" "novabot_hours" {
  count = var.enable_connect ? 1 : 0
  
  instance_id = aws_connect_instance.novabot_instance[0].id
  name        = "NovaBot Support Hours"
  description = "Operating hours for NovaBot support"
  time_zone   = "EST"

  config {
    day = "MONDAY"
    end_time {
      hours   = 17
      minutes = 0
    }
    start_time {
      hours   = 9
      minutes = 0
    }
  }

  config {
    day = "TUESDAY"
    end_time {
      hours   = 17
      minutes = 0
    }
    start_time {
      hours   = 9
      minutes = 0
    }
  }

  config {
    day = "WEDNESDAY"
    end_time {
      hours   = 17
      minutes = 0
    }
    start_time {
      hours   = 9
      minutes = 0
    }
  }

  config {
    day = "THURSDAY"
    end_time {
      hours   = 17
      minutes = 0
    }
    start_time {
      hours   = 9
      minutes = 0
    }
  }

  config {
    day = "FRIDAY"
    end_time {
      hours   = 17
      minutes = 0
    }
    start_time {
      hours   = 9
      minutes = 0
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-hours"
  })
}

# Queue for routing
resource "aws_connect_queue" "novabot_queue" {
  count = var.enable_connect ? 1 : 0
  
  instance_id                 = aws_connect_instance.novabot_instance[0].id
  name                       = "NovaBot Support Queue"
  description                = "Main support queue for NovaBot"
  hours_of_operation_id      = aws_connect_hours_of_operation.novabot_hours[0].hours_of_operation_id
  max_contacts              = 50
  
  outbound_caller_config {
    outbound_caller_id_name         = "NovaBot Support"
    outbound_caller_id_number_id    = null  # Set if you have a phone number
    outbound_flow_id               = null   # Set if you have an outbound flow
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-queue"
  })
}

# Lambda Function Permission for Amazon Connect
resource "aws_lambda_permission" "connect_invoke_lambda" {
  count = var.enable_connect ? 1 : 0
  
  statement_id  = "AllowExecutionFromConnect"
  action        = "lambda:InvokeFunction"
  function_name = split(":", var.lex_lambda_arn)[6]
  principal     = "connect.amazonaws.com"
  source_arn    = aws_connect_instance.novabot_instance[0].arn
}

# Contact Flow for Web Chat
resource "aws_connect_contact_flow" "webchat_flow" {
  count = var.enable_connect ? 1 : 0
  
  instance_id = aws_connect_instance.novabot_instance[0].id
  name        = "NovaBot WebChat Flow"
  description = "Contact flow for web chat integration"
  type        = "CONTACT_FLOW"
  
  content = jsonencode({
    Version = "2019-10-30"
    StartAction = "StartWebChat"
    Actions = [
      {
        Identifier = "StartWebChat"
        Type       = "MessageParticipant"
        Parameters = {
          Text = "Hello! I'm connecting you to NovaBot, your AI support assistant. How can I help you today?"
        }
        Transitions = {
          NextAction = "InvokeNovaBot"
        }
      },
      {
        Identifier = "InvokeNovaBot"
        Type       = "InvokeLambdaFunction"
        Parameters = {
          LambdaFunctionARN = var.lex_lambda_arn
          InvocationTimeLimitSeconds = 30
          LambdaInvocationAttributes = {
            source = "connect_webchat"
          }
        }
        Transitions = {
          NextAction = "CheckResponse"
          Errors = [
            {
              ErrorType = "NoMatchingError"
              NextAction = "ErrorHandler"
            }
          ]
        }
      },
      {
        Identifier = "CheckResponse"
        Type       = "Compare"
        Parameters = {
          ComparisonValue = "$.External.success"
        }
        Transitions = {
          NextAction = "EndChat"
          Conditions = [
            {
              NextAction = "ErrorHandler"
              Condition = {
                Operator = "Equals"
                Operands = ["false"]
              }
            }
          ]
        }
      },
      {
        Identifier = "ErrorHandler"
        Type       = "MessageParticipant"
        Parameters = {
          Text = "I apologize, but I'm experiencing technical difficulties. Let me connect you to a human agent."
        }
        Transitions = {
          NextAction = "TransferToAgent"
        }
      },
      {
        Identifier = "TransferToAgent"
        Type       = "TransferContactToQueue"
        Parameters = {
          QueueId = aws_connect_queue.novabot_queue[0].queue_id
        }
        Transitions = {
          NextAction = "EndChat"
        }
      },
      {
        Identifier = "EndChat"
        Type       = "DisconnectParticipant"
        Parameters = {}
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-webchat-flow"
  })
}

# Phone Number (placeholder - requires actual phone number provisioning)
# Uncomment and configure when ready to use
# resource "aws_connect_phone_number" "novabot_number" {
#   count = var.enable_connect && var.inbound_calls_enabled ? 1 : 0
#   
#   country_code = "US"
#   type         = "DID"
#   target_arn   = aws_connect_instance.novabot_instance[0].arn
#   description  = "NovaBot Support Phone Number"
#   
#   tags = merge(var.tags, {
#     Name = "${var.project_name}-${var.environment}-phone"
#   })
# }

# Contact Flow for Phone Calls
resource "aws_connect_contact_flow" "phone_flow" {
  count = var.enable_connect && var.inbound_calls_enabled ? 1 : 0
  
  instance_id = aws_connect_instance.novabot_instance[0].id
  name        = "NovaBot Phone Support Flow"
  description = "Contact flow for inbound phone calls"
  type        = "CONTACT_FLOW"
  
  content = jsonencode({
    Version = "2019-10-30"
    StartAction = "StartPhone"
    Actions = [
      {
        Identifier = "StartPhone"
        Type       = "MessageParticipant"
        Parameters = {
          Text = "Thank you for calling NovaBot Support. I'm your AI assistant and I'm here to help."
          TextToSpeechType = "text"
        }
        Transitions = {
          NextAction = "CheckBusinessHours"
        }
      },
      {
        Identifier = "CheckBusinessHours"
        Type       = "CheckHoursOfOperation"
        Parameters = {
          HoursOfOperationId = aws_connect_hours_of_operation.novabot_hours[0].hours_of_operation_id
        }
        Transitions = {
          NextAction = "InvokeNovaBot"
          Conditions = [
            {
              NextAction = "AfterHours"
              Condition = {
                Operator = "Equals"
                Operands = ["False"]
              }
            }
          ]
        }
      },
      {
        Identifier = "AfterHours"
        Type       = "MessageParticipant"
        Parameters = {
          Text = "Thank you for calling. Our support hours are Monday through Friday, 9 AM to 5 PM Eastern Time. You can also visit our website for 24/7 AI assistance."
          TextToSpeechType = "text"
        }
        Transitions = {
          NextAction = "EndCall"
        }
      },
      {
        Identifier = "InvokeNovaBot"
        Type       = "InvokeLambdaFunction"
        Parameters = {
          LambdaFunctionARN = var.lex_lambda_arn
          InvocationTimeLimitSeconds = 30
          LambdaInvocationAttributes = {
            source = "connect_phone"
          }
        }
        Transitions = {
          NextAction = "TransferToAgent"
          Errors = [
            {
              ErrorType = "NoMatchingError"
              NextAction = "TransferToAgent"
            }
          ]
        }
      },
      {
        Identifier = "TransferToAgent"
        Type       = "TransferContactToQueue"
        Parameters = {
          QueueId = aws_connect_queue.novabot_queue[0].queue_id
        }
        Transitions = {
          NextAction = "EndCall"
        }
      },
      {
        Identifier = "EndCall"
        Type       = "DisconnectParticipant"
        Parameters = {}
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-phone-flow"
  })
}

# Security Profile for Connect Users (future use)
resource "aws_connect_security_profile" "novabot_agent_profile" {
  count = var.enable_connect ? 1 : 0
  
  instance_id = aws_connect_instance.novabot_instance[0].id
  name        = "NovaBot Agent Profile"
  description = "Security profile for NovaBot support agents"

  permissions = [
    "BasicAgentAccess",
    "OutboundCallAccess"
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-agent-profile"
  })
}

# Routing Profile
resource "aws_connect_routing_profile" "novabot_routing" {
  count = var.enable_connect ? 1 : 0
  
  instance_id               = aws_connect_instance.novabot_instance[0].id
  name                     = "NovaBot Routing Profile"
  default_outbound_queue_id = aws_connect_queue.novabot_queue[0].queue_id
  description              = "Routing profile for NovaBot agents"

  media_concurrencies {
    channel     = "VOICE"
    concurrency = 1
  }

  media_concurrencies {
    channel     = "CHAT"
    concurrency = 3
  }

  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.novabot_queue[0].queue_id
  }

  queue_configs {
    channel  = "CHAT"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.novabot_queue[0].queue_id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-routing"
  })
}

# CloudWatch Log Group for Contact Flow Logs
resource "aws_cloudwatch_log_group" "connect_logs" {
  count = var.enable_connect && var.contact_flow_logs_enabled ? 1 : 0
  
  name              = "/aws/connect/${local.connect_instance_alias}"
  retention_in_days = var.environment == "prod" ? 30 : 14

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-connect-logs"
  })
}

# Data source for current AWS region
data "aws_region" "current" {}