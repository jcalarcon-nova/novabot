output "connect_instance_id" {
  description = "ID of the Amazon Connect instance"
  value       = var.enable_connect ? aws_connect_instance.novabot_instance[0].id : null
}

output "connect_instance_arn" {
  description = "ARN of the Amazon Connect instance"
  value       = var.enable_connect ? aws_connect_instance.novabot_instance[0].arn : null
}

output "connect_instance_alias" {
  description = "Alias of the Amazon Connect instance"
  value       = var.enable_connect ? aws_connect_instance.novabot_instance[0].instance_alias : null
}

output "connect_service_role" {
  description = "Service role ARN for the Connect instance"
  value       = var.enable_connect ? aws_connect_instance.novabot_instance[0].service_role : null
}

output "webchat_flow_id" {
  description = "ID of the webchat contact flow"
  value       = var.enable_connect ? aws_connect_contact_flow.webchat_flow[0].contact_flow_id : null
}

output "phone_flow_id" {
  description = "ID of the phone contact flow"
  value       = var.enable_connect && var.inbound_calls_enabled ? aws_connect_contact_flow.phone_flow[0].contact_flow_id : null
}

output "support_queue_id" {
  description = "ID of the main support queue"
  value       = var.enable_connect ? aws_connect_queue.novabot_queue[0].queue_id : null
}

output "support_queue_arn" {
  description = "ARN of the main support queue"
  value       = var.enable_connect ? aws_connect_queue.novabot_queue[0].arn : null
}

output "hours_of_operation_id" {
  description = "ID of the hours of operation"
  value       = var.enable_connect ? aws_connect_hours_of_operation.novabot_hours[0].hours_of_operation_id : null
}

output "routing_profile_id" {
  description = "ID of the routing profile"
  value       = var.enable_connect ? aws_connect_routing_profile.novabot_routing[0].routing_profile_id : null
}

output "security_profile_id" {
  description = "ID of the security profile"
  value       = var.enable_connect ? aws_connect_security_profile.novabot_agent_profile[0].security_profile_id : null
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = var.enable_connect && var.contact_flow_logs_enabled ? aws_cloudwatch_log_group.connect_logs[0].name : null
}

output "connect_enabled" {
  description = "Whether Amazon Connect is enabled"
  value       = var.enable_connect
}

output "setup_instructions" {
  description = "Instructions for enabling Amazon Connect"
  value = var.enable_connect ? null : <<-EOT
    Amazon Connect is currently disabled. To enable it:
    
    1. Set enable_connect = true in your Terraform configuration
    2. Configure connect_instance_alias if desired
    3. Run terraform plan and terraform apply
    4. Configure phone numbers if needed for voice support
    5. Set up agents and users in the Connect console
    
    Note: Amazon Connect instances cannot be easily destroyed once created.
    Plan your deployment carefully.
  EOT
}