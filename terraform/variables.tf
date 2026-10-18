variable "project_id" {
  description = "Google Cloud Project ID hosting the Open5GS 5G SA Core"
  type        = string
}

variable "region" {
  description = "Primary GCP Region for the 100% Public Cloud 5G Core deployment"
  type        = string
  default     = "us-central1"
}

variable "zones" {
  description = "Availability zones within the region for Multi-Zone High Availability"
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b", "us-central1-c"]
}

variable "ran_cidr" {
  description = "External RAN (gNodeB) CIDR range reaching N2 (SCTP) and N3 (GTP-U) over HA VPN / Cloud Interconnect"
  type        = string
  default     = "172.16.0.0/16"
}

variable "ue_pool_cidr" {
  description = "UE PDU Session IPv4 pool assigned by SMF/UPF on ogstun"
  type        = string
  default     = "10.45.0.0/16"
}

variable "plmn_mcc" {
  description = "3GPP Mobile Country Code (MCC)"
  type        = string
  default     = "999"
}

variable "plmn_mnc" {
  description = "3GPP Mobile Network Code (MNC)"
  type        = string
  default     = "70"
}
