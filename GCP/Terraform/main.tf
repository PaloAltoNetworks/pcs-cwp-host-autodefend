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
    echo "IyEvYmluL2Jhc2gKIyBWYXJpYWJsZXMKU0VDUkVUX1BST0pFQ1RfSUQ9IiQxIgpTRUNSRVRfTkFNRT0iJDIiCltbIC16ICIkMyIgXV0gJiYgTE9HX0ZJTEU9Ii90bXAvaW5zdGFsbF9kZWZlbmRlci5sb2ciIHx8IExPR19GSUxFPSIkMyIKCiMgSW5zdGFsbGluZyBqcSBhbmQgY3VybCAoaWYgbm90IGluc3RhbGxlZCkKbm90X2luc3RhbGxlZF9wYWNrYWdlcz0iIgppZiAhIGNvbW1hbmQgLXYgY3VybCAmPiAkTE9HX0ZJTEU7IHRoZW4gbm90X2luc3RhbGxlZF9wYWNrYWdlcys9ImN1cmwiOyBmaQppZiAhIGNvbW1hbmQgLXYganEgJj4gJExPR19GSUxFOyB0aGVuIG5vdF9pbnN0YWxsZWRfcGFja2FnZXMrPSIganEiOyBmaQoKaWYgW1sgLW4gIiRub3RfaW5zdGFsbGVkX3BhY2thZ2VzIiBdXQp0aGVuCiAgICBlY2hvICJQYWNrYWdlcyAkbm90X2luc3RhbGxlZF9wYWNrYWdlcyBub3QgaW5zdGFsbGVkLiBJbnN0YWxsaW5nIHBlbmRpbmcgcGFja2FnZXMuLi4iCiAgICBpZiBjb21tYW5kIC12IHl1bSA+ICRMT0dfRklMRSAKICAgIHRoZW4KICAgICAgICBldmFsICJzdWRvIHl1bSBpbnN0YWxsIC15ICRub3RfaW5zdGFsbGVkX3BhY2thZ2VzIiA+ICRMT0dfRklMRQogICAgZWxzZQogICAgICAgIGV2YWwgInN1ZG8gYXB0IHVwZGF0ZSAmPiAkTE9HX0ZJTEUgJiYgc3VkbyBhcHQgaW5zdGFsbCAteSAkbm90X2luc3RhbGxlZF9wYWNrYWdlcyAmPiAkTE9HX0ZJTEUiCiAgICBmaQpmaQoKIyBPYnRhaW4gYWNjZXNzIHRva2VuCkFDQ0VTU19UT0tFTj0kKGN1cmwgLXMgLUggIk1ldGFkYXRhLUZsYXZvcjogR29vZ2xlIiAiaHR0cDovL21ldGFkYXRhL2NvbXB1dGVNZXRhZGF0YS92MS9pbnN0YW5jZS9zZXJ2aWNlLWFjY291bnRzL2RlZmF1bHQvdG9rZW4iIHwganEgLXIgJy5hY2Nlc3NfdG9rZW4nKQoKIyBSZXRyaWV2ZSB0aGUgc2VjcmV0ClNFQ1JFVF9KU09OPSQoY3VybCAtcyAtSCAiQXV0aG9yaXphdGlvbjogQmVhcmVyICRBQ0NFU1NfVE9LRU4iICJodHRwczovL3NlY3JldG1hbmFnZXIuZ29vZ2xlYXBpcy5jb20vdjEvcHJvamVjdHMvJFNFQ1JFVF9QUk9KRUNUX0lEL3NlY3JldHMvJFNFQ1JFVF9OQU1FL3ZlcnNpb25zL2xhdGVzdDphY2Nlc3MiIHwganEgLXIgJy5wYXlsb2FkLmRhdGEnIHwgYmFzZTY0IC1kKQoKIyBFeHBvcnQgdGhlIHNlY3JldCB2YXJpYWJsZXMKUENDX1VSTD0kKGVjaG8gIiRTRUNSRVRfSlNPTiIgfCBqcSAtciAnLlBDQ19VUkwnKQpQQ0NfVVNFUj0kKGVjaG8gIiRTRUNSRVRfSlNPTiIgfCBqcSAtciAnLlBDQ19VU0VSJykKUENDX1BBU1M9JChlY2hvICIkU0VDUkVUX0pTT04iIHwganEgLXIgJy5QQ0NfUEFTUycpClBDQ19TQU49JChlY2hvICIkU0VDUkVUX0pTT04iIHwganEgLXIgJy5QQ0NfU0FOJykKCltbIC16ICIkUENDX1VSTCIgXV0gJiYgZWNobyAiUGxlYXNlIHZlcmlmeSB0aGF0IHRoZSBTZXJ2aWNlIEFjY291bnQgdXNlZCBmb3IgdGhpcyBWTSBoYXMgYWNjZXNzIHRvIHRoZSBTZWNyZXQsIHRoZSBzZWNyZXQgJFNFQ1JFVF9OQU1FIGluIHRoZSBwcm9qZWN0ICRTRUNSRVRfUFJPSkVDVF9JRCBleGlzdHMgYW5kIHRoYXQgdGhlIGFjY2VzcyB0byB0aGUgR0NQIEFQSXMgaXMgZ2xvYmFsIiA+ICRMT0dfRklMRSAmJiBleGl0IDEKCiMgUmV0cmlldmluZyBQcmlzbWEgQ2xvdWQgQ29uc29sZSBUb2tlbgp0b2tlbj0kKGN1cmwgLXMgLWsgIiRQQ0NfVVJML2FwaS92MS9hdXRoZW50aWNhdGUiIC1YIFBPU1QgLUggIkNvbnRlbnQtVHlwZTogYXBwbGljYXRpb24vanNvbiIgLWQgJ3sidXNlcm5hbWUiOiInIiRQQ0NfVVNFUiInIiwgInBhc3N3b3JkIjoiJyIkUENDX1BBU1MiJyJ9JyB8IGpxIC1yICcudG9rZW4nKQoKW1sgLXogIiR0b2tlbiIgXV0gJiYgZWNobyAiSW52YWxpZCBjcmVkZW50aWFscy4gUGxlYXNlIHZlcmlmeSBpZiB0aGUgY3JlZGVudGlhbHMgZXhpc3RzIGFuZCBhcmUgbm90IGV4cGlyZWQiID4gJExPR19GSUxFICYmIGV4aXQgMQoKIyBJbnN0YWxsaW5nIGRlZmVuZGVyCmlmIHN1ZG8gZG9ja2VyIHBzICY+ICRMT0dfRklMRTsgdGhlbiBhcmdzPSIiOyBlbHNlIGFyZ3M9Ii0taW5zdGFsbC1ob3N0IjsgZmkKY3VybCAtc1NMIC1rIC0taGVhZGVyICJhdXRob3JpemF0aW9uOiBCZWFyZXIgJHRva2VuIiAtWCBQT1NUICIkUENDX1VSTC9hcGkvdjEvc2NyaXB0cy9kZWZlbmRlci5zaCIgfCBzdWRvIGJhc2ggLXMgLS0gLWMgIiRQQ0NfU0FOIiAtbSAtdSAkYXJncyA+ICRMT0dfRklMRQoKIyBSZW1vdmluZyBJbnN0YWxsZWQgcGFja2FnZXMKaWYgW1sgLW4gIiRub3RfaW5zdGFsbGVkX3BhY2thZ2VzIiBdXQp0aGVuCiAgICBlY2hvICJSZW1vdmluZyB0aGUgcGFja2FnZXMgJG5vdF9pbnN0YWxsZWRfcGFja2FnZXMgc2luY2Ugd2VyZSBub3QgaW5zdGFsbGVkLi4uIgogICAgaWYgY29tbWFuZCAtdiB5dW0gPiAkTE9HX0ZJTEUKICAgIHRoZW4KICAgICAgICBzdWRvIHl1bSByZW1vdmUgLXkgJG5vdF9pbnN0YWxsZWRfcGFja2FnZXMgJj4gJExPR19GSUxFCiAgICBlbHNlCiAgICAgICAgc3VkbyBhcHQgcmVtb3ZlIC15ICRub3RfaW5zdGFsbGVkX3BhY2thZ2VzICY+ICRMT0dfRklMRQogICAgZmkKZmk=" | base64 -d > /tmp/install_defender.sh
    bash /tmp/install_defender.sh ${var.secret_project_id} ${var.secret_name}
    rm /tmp/install_defender.sh
  EOF

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = data.google_service_account.pcc_secret_access.email
    scopes = ["cloud-platform"]
  }
}