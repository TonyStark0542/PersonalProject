variable "gcp_project_id" {
  type        = string
  description = "The specific ID of your active GCP playground project workspace"
  default     = "playground-s-11-5320c2a2" # Put your active project ID here
}

variable "gcp_region" {
  type        = string
  description = "The target cloud region for deployment execution loops"
  default     = "us-central1"
}

variable "gcp_zone" {
  type        = string
  description = "The explicit physical hardware zone for instance provisioning"
  default     = "us-central1-a"
}

variable "machine_type" {
  type        = string
  description = "The underlying compute engine size scaling parameter"
  default     = "e2-medium"
}

variable "app_port" {
  type        = string
  description = "The ingress public delivery port exposed by your Docker architecture"
  default     = "5000"
}
