# Create a new check for the target endpoint in a specific region
resource "digitalocean_uptime_check" "foobar" {
  name    = "us-east-check"
  target  = "https://www.tfvisualizer.com"
  regions = ["us_east"]
}

# Create a latency alert for the uptime check
resource "digitalocean_uptime_alert" "alert-example" {
  name       = "latency-alert"
  check_id   = digitalocean_uptime_check.foobar.id
  type       = "latency"
  threshold  = 300
  comparison = "greater_than"
  period     = "2m"
  notifications {
    email = [var.email_alert]
    slack {
      channel = "alerts"
      url     = var.slack_url
    }
  }
}
