# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
}

variable "prisma_compute_url" {
  description = "Prisma Cloud Compute URL"
  sensitive   = true
}

variable "prisma_console_name" {
  description = "Prisma Cloud Compute Console Name"
  sensitive   = true
}

variable "prisma_ak" {
  description = "Prisma Cloud Service Account Access Key"
  sensitive   = true
}

variable "prisma_sk" {
  description = "Prisma Cloud Service Account Secret Key"
  sensitive   = true
}
