output "gke_cluster_name" {
  description = "GKE 5G Core cluster name"
  value       = google_container_cluster.open5gs_cluster.name
}

output "gke_cluster_location" {
  description = "GKE 5G Core cluster region"
  value       = google_container_cluster.open5gs_cluster.location
}

output "firestore_database_uid" {
  description = "Cloud Firestore Enterprise (MongoDB Compatible) database UID used to construct the MongoDB connection URI"
  value       = google_firestore_database.open5gs_mongodb_compat.uid
}

output "firestore_mongodb_endpoint" {
  description = "Cloud Firestore MongoDB-compatible wire-protocol hostname"
  value       = "${google_firestore_database.open5gs_mongodb_compat.uid}.${var.region}.firestore.goog:443"
}

output "firestore_mongodb_uri" {
  description = "Complete SCRAM-SHA-256 MongoDB-compatible URI for Open5GS NFs, dbctl, and WebUI"
  value       = "mongodb://${google_firestore_user_creds.open5gs_db_user.name}:${urlencode(google_firestore_user_creds.open5gs_db_user.secure_password)}@${google_firestore_database.open5gs_mongodb_compat.uid}.${var.region}.firestore.goog:443/${google_firestore_database.open5gs_mongodb_compat.name}?loadBalanced=true&authMechanism=SCRAM-SHA-256&tls=true&retryWrites=false"
  sensitive   = true
}

output "redis_host" {
  description = "Cloud Memorystore Redis primary endpoint IP"
  value       = google_redis_instance.open5gs_inmemory_cache.host
}

output "redis_port" {
  description = "Cloud Memorystore Redis port"
  value       = google_redis_instance.open5gs_inmemory_cache.port
}

output "monitoring_dashboard_id" {
  description = "Google Cloud Monitoring 'Open5GS' dashboard resource ID"
  value       = google_monitoring_dashboard.open5gs_dashboard.id
}

output "monitoring_dashboard_console_url" {
  description = "Direct Google Cloud Console URL for the Open5GS Monitoring Dashboard"
  value       = "https://console.cloud.google.com/monitoring/dashboards/custom/${basename(google_monitoring_dashboard.open5gs_dashboard.id)}?project=${var.project_id}"
}
