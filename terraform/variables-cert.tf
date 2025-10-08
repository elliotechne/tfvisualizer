# Certificate and DNS Variables

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt / ZeroSSL notifications"
  type        = string
}

variable "zerossl_eab_kid" {
  description = "ZeroSSL External Account Binding Key ID"
  type        = string
  sensitive   = true
}

variable "zerossl_eab_hmac_key" {
  description = "ZeroSSL External Account Binding HMAC Key"
  type        = string
  sensitive   = true
}
