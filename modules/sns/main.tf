#######################################################################
# SNS Topic for CloudWatch Alarms                                     #
#                                                                     #
# Creates an SNS topic for CloudWatch alarm notifications. If an      #
# email address is provided, it will be subscribed to the topic.      #
# Email subscriptions require manual confirmation via AWS email.      #
#######################################################################
resource "aws_sns_topic" "cloudwatch_alarms" {
  name = "${var.project_name}-cloudwatch-alarms"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-cloudwatch-alarms"
    }
  )
}

resource "aws_sns_topic_subscription" "cloudwatch_alarms_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.cloudwatch_alarms.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
