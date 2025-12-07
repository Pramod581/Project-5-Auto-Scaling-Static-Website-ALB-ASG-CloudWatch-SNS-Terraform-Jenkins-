output "alb_url" { value = aws_lb.alb.dns_name }
output "asg_name" { value = aws_autoscaling_group.asg.name }
output "sns_topic_arn" { value = aws_sns_topic.alerts.arn }