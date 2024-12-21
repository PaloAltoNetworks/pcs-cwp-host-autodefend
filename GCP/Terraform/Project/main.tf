resource "google_project" "new_project" {
  name            = var.project_name
  project_id      = var.project_id
  folder_id       = var.folder_id
}

resource "google_service_account" "service_account" {
  account_id   = var.service_account_name
  display_name = "VM PCC Secret Access"
  project      = var.project_id
  depends_on = [
    google_project.new_project
  ]
}

resource "google_project_iam_member" "project" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.service_account.email}"

  depends_on = [
    google_service_account.service_account
  ]
}

resource "google_secret_manager_secret_iam_member" "member" {
  project   = var.secret_project_id
  secret_id = var.secret_name
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.service_account.email}"

  depends_on = [
    google_service_account.service_account
  ]
}
