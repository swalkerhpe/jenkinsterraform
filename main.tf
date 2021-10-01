provider "google" {
 credentials = "${file("./creds/serviceaccount.json")}"
 #credentials = var.my_key
 project     = var.project
 region      = var.region
}

resource "google_compute_instance_template" "template" {
  name  = "instance-template-nginx"
  machine_type = var.machine_type
  region = var.region
  tags = var.tags

  disk {
    source_image      = var.image
    auto_delete       = true
    boot              = true

  }

  metadata_startup_script = var.metadata_startup_script

  network_interface {
   network = var.network_type

   access_config {
   }
  }
}

resource "google_compute_region_instance_group_manager" "appserver" {
    base_instance_name               = "migbase"
    distribution_policy_target_shape = "EVEN"
    distribution_policy_zones        = [
        "europe-west2-a",
        "europe-west2-b",
        "europe-west2-c",
    ]
    
    
    name                             = "mig1"
    project                          = "stevewalkerapp1"
    region                           = "europe-west2"
    #target_pools                     = []
    target_size                      = 3
    #wait_for_instances               = false
    #wait_for_instances_status        = "STABLE"

    auto_healing_policies {
        health_check      = google_compute_health_check.autohealing.id
        initial_delay_sec = 300
    }

    timeouts {}

    update_policy {
        instance_redistribution_type = "PROACTIVE"
        max_surge_fixed              = 6
        max_unavailable_fixed        = 3
        minimal_action               = "REPLACE"
        replacement_method           = "SUBSTITUTE"
        type                         = "OPPORTUNISTIC"
    }

    version {
        instance_template = google_compute_instance_template.template.id
    }
}

/*resource "google_compute_autoscaler" "foobar" {
  name   = "my-autoscaler"
  zone   = var.zone
  target = google_compute_region_instance_group_manager.appserver.id

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.5
    }
  }
}*/

resource "google_compute_health_check" "autohealing" {
    check_interval_sec  = 10
    healthy_threshold   = 2
    
    name                = "autohealing"
    project             = "stevewalkerapp1"
    timeout_sec         = 5
    unhealthy_threshold = 2

    log_config {
        enable = false
    }

    tcp_health_check {
        port         = 80
        proxy_header = "NONE"
    }

    timeouts {}
}



resource "google_compute_backend_service" "default" {
    affinity_cookie_ttl_sec         = 0
    connection_draining_timeout_sec = 300
    custom_request_headers          = []
    custom_response_headers         = []
    enable_cdn                      = false
    health_checks                   = [
        google_compute_health_check.autohealing.id,
    ]
    load_balancing_scheme           = "EXTERNAL"
    name                            = "terraformbackend"
    port_name                       = "http"
    project                         = "stevewalkerapp1"
    protocol                        = "HTTP"
    session_affinity                = "NONE"
    timeout_sec                     = 30

    backend {
        balancing_mode               = "UTILIZATION"
        capacity_scaler              = 1
        group                        = google_compute_region_instance_group_manager.appserver.instance_group
        max_connections              = 0
        max_connections_per_endpoint = 0
        max_connections_per_instance = 0
        max_rate                     = 0
        max_rate_per_endpoint        = 0
        max_rate_per_instance        = 0
        max_utilization              = 0.8
    }

    log_config {
        enable      = false
        sample_rate = 0
    }

    timeouts {}
}

resource "google_compute_global_forwarding_rule" "default" {
  name       = "global-rule"
  target     = google_compute_target_http_proxy.default.id
  port_range = "80"
}

resource "google_compute_target_http_proxy" "default" {
  name        = "target-proxy"
  description = "a description"
  url_map     = google_compute_url_map.default.id
}

resource "google_compute_url_map" "default" {
  name            = "url-map-target-proxy"
  description     = "a description"
  default_service = google_compute_backend_service.default.id
}


