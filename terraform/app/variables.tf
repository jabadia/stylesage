variable "project" {
  description = "Project"
  type        = string
  default     = "iotd"
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-1"
}

variable "aws_tags" {
  description = "AWS Tags for resources"
  type        = map(any)
  default = {
    terraform       = "true"
    terraform_state = "iotd"
  }
}

variable "image" {
  description = "Docker image"
  type        = string
}
