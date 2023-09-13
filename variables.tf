variable "log_group_prefix" {
  default     = "/poc"
  type        = string
  description = "prefix for all log groups created for the project"
}

variable "trail_name" {
  default     = "poc_mgt_trail"
  type        = string
  description = "prefix for all log groups created for the project"
}
variable "trail_prefix" {
  default     = "prefix"
  type        = string
  description = "prefix for all log groups created for the project"
}
variable "log_group__api_trail_events" {
  default     = "api-trail-events"
  type        = string
  description = "prefix for all log groups created for the project"
}
variable "lambda__trail_event_to_log_stream__name" {
  default     = "trail_event_to_log_stream"
  type        = string
  description = "prefix for all log groups created for the project"
}
