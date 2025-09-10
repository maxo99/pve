# variable "api_credentials_path" {
#   description = "Path in Vault where credentials are stored for Proxmox"
#   type        = string
# }

variable "vault_retry" {
  description = "Number of retry attempts to retrieve secrets in case of error"
  type        = number
  default     = 3
}
