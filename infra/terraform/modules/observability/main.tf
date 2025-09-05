# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "novabot_dashboard" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            for function_name in var.lambda_function_names : 
            ["AWS/Lambda", "Invocations", "FunctionName", function_name]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-1"
          title  = "Lambda Invocations"
        }
      }
    ]
  })
}

# CloudWatch Alarms for Lambda errors
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  count = length(var.lambda_function_names)
  
  alarm_name          = "${var.project_name}-${var.environment}-lambda-errors-${var.lambda_function_names[count.index]}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors lambda errors"
  alarm_actions       = []

  dimensions = {
    FunctionName = var.lambda_function_names[count.index]
  }

  tags = var.tags
}