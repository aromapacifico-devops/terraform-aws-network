# Data sources of the module. Only computational ones belong here, external IDs arrive as variables.
data "aws_region" "current" {
  provider = aws.project
}
