provider "google" {
  credentials = "${file("${lookup(var.credential, "data")}")}"
  project     = "${lookup(var.project, "${terraform.workspace}")}"
  region      = "asia-northeast1"
}

data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/files/functions.zip"
}

resource "google_storage_bucket" "slack_functions_bucket" {
  name          = "${lookup(var.project, "${terraform.workspace}")}-scheduler-bucket"
  project       = "${lookup(var.project, "${terraform.workspace}")}"
  location      = "asia"
  force_destroy = true
}

resource "google_storage_bucket_object" "functions_zip" {
  name   = "functions.zip"
  bucket = "${google_storage_bucket.slack_functions_bucket.name}"
  source = "${path.module}/files/functions.zip"
}

resource "google_pubsub_topic" "slack_notify" {
  name    = "slack-notify"
  project = "${lookup(var.project, "${terraform.workspace}")}"
}

resource "google_cloudfunctions_function" "slack_notification" {
  name        = "SlackNotification"
  project     = "${lookup(var.project, "${terraform.workspace}")}"
  region      = "asia-northeast1"
  runtime     = "go111"
  entry_point = "SlackNotification"

  source_archive_bucket = "${google_storage_bucket.slack_functions_bucket.name}"
  source_archive_object = "${google_storage_bucket_object.functions_zip.name}"

  environment_variables = {
    SLACK_WEBHOOK_URL = "${lookup(var.webhook, "url")}"
  }

  labels = {
    apps = "slack"
  }

  event_trigger {
    event_type = "providers/cloud.pubsub/eventTypes/topic.publish"
    resource   = "${google_pubsub_topic.slack_notify.name}"
  }
}

resource "google_cloud_scheduler_job" "slack-notify-scheduler" {
  name        = "slack-notify-daily"
  project     = "${lookup(var.project, "${terraform.workspace}")}"
  schedule    = "0 8 * * *"
  description = "suggesting your morning/lunch/dinner"
  time_zone   = "Asia/Tokyo"

  pubsub_target {
    topic_name = "${google_pubsub_topic.slack_notify.id}"
    data       = "${base64encode("{\"mention\":\"channel\",\"channel\":\"random\"}")}"
  }
}
