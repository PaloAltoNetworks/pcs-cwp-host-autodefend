data "google_service_account" "pcc_secret_access" {
  account_id = var.service_account_name
}

resource "google_compute_instance" "my-instance" {
  name         = "terraform-gcp-instance"
  machine_type = "n2-standard-2"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = <<-EOF
    echo "IyEvYmluL2Jhc2gKIyBWYXJpYWJsZXMKU0VDUkVUX1BST0pFQ1RfSUQ9IiQxIgpTRUNSRVRfTkFNRT0iJDIiCgojIEluc3RhbGxpbmcganEgYW5kIGN1cmwgKGlmIG5vdCBpbnN0YWxsZWQpCm5vdF9pbnN0YWxsZWRfcGFja2FnZXM9IiIKaWYgISBjb21tYW5kIC12IGN1cmwgJj4gL2Rldi9udWxsOyB0aGVuIG5vdF9pbnN0YWxsZWRfcGFja2FnZXMrPSJjdXJsIjsgZmkKaWYgISBjb21tYW5kIC12IGpxICY+IC9kZXYvbnVsbDsgdGhlbiBub3RfaW5zdGFsbGVkX3BhY2thZ2VzKz0iIGpxIjsgZmkKCmlmIFtbIC1uICIkbm90X2luc3RhbGxlZF9wYWNrYWdlcyIgXV0KdGhlbgogICAgZWNobyAiUGFja2FnZXMgJG5vdF9pbnN0YWxsZWRfcGFja2FnZXMgbm90IGluc3RhbGxlZC4gSW5zdGFsbGluZyBwZW5kaW5nIHBhY2thZ2VzLi4uIgogICAgaWYgY29tbWFuZCAtdiB5dW0gPiAvZGV2L251bGwgCiAgICB0aGVuCiAgICAgICAgc3VkbyB5dW0gaW5zdGFsbCAteSAkbm90X2luc3RhbGxlZF9wYWNrYWdlcyA+IC9kZXYvbnVsbAogICAgZWxzZQogICAgICAgIHN1ZG8gYXB0IHVwZGF0ZSAmPiAvZGV2L251bGwgJiYgc3VkbyBhcHQgaW5zdGFsbCAteSAkbm90X2luc3RhbGxlZF9wYWNrYWdlcyAmPiAvZGV2L251bGwKICAgIGZpCmZpCgojIE9idGFpbiBhY2Nlc3MgdG9rZW4KQUNDRVNTX1RPS0VOPSQoY3VybCAtcyAtSCAiTWV0YWRhdGEtRmxhdm9yOiBHb29nbGUiICJodHRwOi8vbWV0YWRhdGEvY29tcHV0ZU1ldGFkYXRhL3YxL2luc3RhbmNlL3NlcnZpY2UtYWNjb3VudHMvZGVmYXVsdC90b2tlbiIgfCBqcSAtciAuYWNjZXNzX3Rva2VuKQoKIyBSZXRyaWV2ZSB0aGUgc2VjcmV0ClNFQ1JFVF9KU09OPSQoY3VybCAtcyAtSCAiQXV0aG9yaXphdGlvbjogQmVhcmVyICRBQ0NFU1NfVE9LRU4iICJodHRwczovL3NlY3JldG1hbmFnZXIuZ29vZ2xlYXBpcy5jb20vdjEvcHJvamVjdHMvJFNFQ1JFVF9QUk9KRUNUX0lEL3NlY3JldHMvJFNFQ1JFVF9OQU1FL3ZlcnNpb25zL2xhdGVzdDphY2Nlc3MiIHwganEgLXIgLnBheWxvYWQuZGF0YSB8IGJhc2U2NCAtLWRlY29kZSkKCiMgRXhwb3J0IHRoZSBzZWNyZXQgdmFyaWFibGVzClBDQ19VUkw9JChlY2hvICRTRUNSRVRfSlNPTiB8IGpxIC1yICcuUENDX1VSTCcpClBDQ19VU0VSPSQoZWNobyAkU0VDUkVUX0pTT04gfCBqcSAtciAnLlBDQ19VU0VSJykKUENDX1BBU1M9JChlY2hvICRTRUNSRVRfSlNPTiB8IGpxIC1yICcuUENDX1BBU1MnKQpQQ0NfU0FOPSQoZWNobyAkU0VDUkVUX0pTT04gfCBqcSAtciAnLlBDQ19TQU4nKQoKIyBSZXRyaWV2aW5nIFByaXNtYSBDbG91ZCBDb25zb2xlIFRva2VuCnRva2VuPSQoY3VybCAtcyAtayAkUENDX1VSTC9hcGkvdjEvYXV0aGVudGljYXRlIC1YIFBPU1QgLUggIkNvbnRlbnQtVHlwZTogYXBwbGljYXRpb24vanNvbiIgLWQgJ3sidXNlcm5hbWUiOiInIiRQQ0NfVVNFUiInIiwgInBhc3N3b3JkIjoiJyIkUENDX1BBU1MiJyJ9JyB8IGpxIC1yICcudG9rZW4nKQoKIyBJbnN0YWxsaW5nIGRlZmVuZGVyCmlmIHN1ZG8gZG9ja2VyIHBzICY+IC9kZXYvbnVsbDsgdGhlbiBhcmdzPSIiOyBlbHNlIGFyZ3M9Ii0taW5zdGFsbC1ob3N0IjsgZmkKY3VybCAtc1NMIC1rIC0taGVhZGVyICJhdXRob3JpemF0aW9uOiBCZWFyZXIgJHRva2VuIiAtWCBQT1NUICRQQ0NfVVJML2FwaS92MS9zY3JpcHRzL2RlZmVuZGVyLnNoIHwgc3VkbyBiYXNoIC1zIC0tIC1jICIkUENDX1NBTiIgLW0gLXUgJGFyZ3MKCiMgUmVtb3ZpbmcgSW5zdGFsbGVkIHBhY2thZ2VzCmlmIFtbIC1uICIkbm90X2luc3RhbGxlZF9wYWNrYWdlcyIgXV0KdGhlbgogICAgZWNobyAiUmVtb3ZpbmcgdGhlIHBhY2thZ2VzICRub3RfaW5zdGFsbGVkX3BhY2thZ2VzIHNpbmNlIHdlcmUgbm90IGluc3RhbGxlZC4uLiIKICAgIGlmIGNvbW1hbmQgLXYgeXVtID4gL2Rldi9udWxsCiAgICB0aGVuCiAgICAgICAgc3VkbyB5dW0gcmVtb3ZlIC15ICRub3RfaW5zdGFsbGVkX3BhY2thZ2VzICY+IC9kZXYvbnVsbAogICAgZWxzZQogICAgICAgIHN1ZG8gYXB0IHJlbW92ZSAteSAkbm90X2luc3RhbGxlZF9wYWNrYWdlcyAmPiAvZGV2L251bGwKICAgIGZpCmZp" | base64 -d > /tmp/install_defender.sh
    bash /tmp/install_defender.sh ${var.secret_project_id} ${var.secret_name}
    rm /tmp/install_defender.sh
  EOF

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = data.google_service_account.pcc_secret_access.email
    scopes = ["cloud-platform"]
  }
}