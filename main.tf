terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "ap-south-1"
}

variable "alert_email" {
  default = "you@example.com"
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "web" {
  ami           = data.aws_ssm_parameter.al2023.value
  instance_type = "t3.micro"
  monitoring    = true
 user_data_replace_on_change = true
  user_data                   = <<-SCRIPT
    #!/bin/bash
    sleep 120
    for i in 1 2; do nohup timeout 1500 sh -c 'while :; do :; done' >/dev/null 2>&1 & done
  SCRIPT
  tags          = { Name = "cpu-alarm-demo" }
}

resource "aws_sns_topic" "alerts" {
  name = "ec2-cpu-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "ec2-cpu-above-70"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 1
  threshold           = 70
  comparison_operator = "GreaterThanThreshold"
  dimensions          = { InstanceId = aws_instance.web.id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

output "instance_id" {
  value = aws_instance.web.id
}
