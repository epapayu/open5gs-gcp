# ==============================================================================
# Google Cloud Monitoring Dashboard: "Open5GS"
# Combines Open5GS Prometheus Telemetry (:9090/metrics via Managed Prometheus)
# and GKE Deployments / StatefulSets / Workloads / Cluster Telemetry
# ==============================================================================

resource "google_monitoring_dashboard" "open5gs_dashboard" {
  project = var.project_id

  dashboard_json = jsonencode({
    displayName = "Open5GS"
    mosaicLayout = {
      columns = 12
      tiles = [
        # ----------------------------------------------------------------------
        # Banner 1: Open5GS 5G SA & EPC Prometheus Telemetry (:9090/metrics)
        # ----------------------------------------------------------------------
        {
          xPos   = 0
          yPos   = 0
          width  = 12
          height = 2
          widget = {
            title = "Open5GS 5G SA & 4G EPC Telemetry (Prometheus :9090/metrics via Managed Service for Prometheus)"
            text = {
              content = "Live 3GPP Release-17 Network Function telemetry scraped every `15s` from `:9090/metrics` (`PodMonitoring/open5gs-nf-metrics`) across **AMF**, **SMF**, **UPF**, **PCF**, and **MME** in namespace `open5gs`."
              format  = "MARKDOWN"
            }
          }
        },

        # Row 1: 4 Executive Scorecards (gNodeBs, AMF Sessions, SMF PDU Sessions, UPF N4 Sessions)
        {
          xPos   = 0
          yPos   = 2
          width  = 3
          height = 3
          widget = {
            title = "Connected 5G gNodeBs (N2 SCTP)"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/gnb/gauge\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        },
        {
          xPos   = 3
          yPos   = 2
          width  = 3
          height = 3
          widget = {
            title = "Active AMF UE Sessions"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/amf_session/gauge\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        },
        {
          xPos   = 6
          yPos   = 2
          width  = 3
          height = 3
          widget = {
            title = "Active SMF PDU Sessions (S-NSSAI)"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/fivegs_smffunction_sm_sessionnbr/gauge\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        },
        {
          xPos   = 9
          yPos   = 2
          width  = 3
          height = 3
          widget = {
            title = "Active UPF User Plane Sessions (N4)"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/fivegs_upffunction_upf_sessionnbr/gauge\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        },

        # Row 2: Prometheus :9090 Scrape Health, AMF Registration/Auth, RAN/EPC Mobility Gauges
        {
          xPos   = 0
          yPos   = 5
          width  = 4
          height = 4
          widget = {
            title = "Prometheus :9090 Scrape Target Health (up)"
            xyChart = {
              chartOptions = { mode = "COLOR" }
              dataSets = [
                {
                  plotType       = "LINE"
                  legendTemplate = "$${metric.labels.top_level_controller_type}/$${metric.labels.top_level_controller_name}: $${metric.labels.pod}"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND resource.label.\"job\"=\"open5gs-nf-metrics\" AND metric.type=\"prometheus.googleapis.com/up/gauge\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields = [
                          "metric.label.\"top_level_controller_type\"",
                          "metric.label.\"top_level_controller_name\"",
                          "metric.label.\"pod\""
                        ]
                      }
                    }
                  }
                }
              ]
              yAxis = { label = "Target Up (1=Healthy)", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 4
          yPos   = 5
          width  = 4
          height = 4
          widget = {
            title = "AMF 5G-AKA Registration & Auth Procedures (:9090)"
            xyChart = {
              chartOptions = { mode = "COLOR" }
              dataSets = [
                {
                  plotType       = "LINE"
                  legendTemplate = "StatefulSet/$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): Init Reg Req/s"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/fivegs_amffunction_rm_reginitreq/counter\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\""]
                      }
                    }
                  }
                },
                {
                  plotType       = "LINE"
                  legendTemplate = "StatefulSet/$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): Init Reg Succ/s"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/fivegs_amffunction_rm_reginitsucc/counter\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\""]
                      }
                    }
                  }
                },
                {
                  plotType       = "LINE"
                  legendTemplate = "StatefulSet/$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): 5G-AKA Auth Req/s"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/fivegs_amffunction_amf_authreq/counter\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\""]
                      }
                    }
                  }
                },
                {
                  plotType       = "LINE"
                  legendTemplate = "StatefulSet/$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): 5G-AKA Auth Fail/s"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/fivegs_amffunction_amf_authfail/counter\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\""]
                      }
                    }
                  }
                }
              ]
              yAxis = { label = "Events / sec", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 8
          yPos   = 5
          width  = 4
          height = 4
          widget = {
            title = "AMF & MME Registered UEs / RAN Peers (:9090)"
            xyChart = {
              chartOptions = { mode = "COLOR" }
              dataSets = [
                {
                  plotType       = "LINE"
                  legendTemplate = "$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): Registered 5G Subscribers"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/fivegs_amffunction_rm_registeredsubnbr/gauge\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\""]
                      }
                    }
                  }
                },
                {
                  plotType       = "LINE"
                  legendTemplate = "$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): 5G RAN UEs (NGAP)"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/ran_ue/gauge\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\""]
                      }
                    }
                  }
                },
                {
                  plotType       = "LINE"
                  legendTemplate = "$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): Connected gNodeBs (N2)"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/gnb/gauge\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\""]
                      }
                    }
                  }
                },
                {
                  plotType       = "LINE"
                  legendTemplate = "$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): 4G MME Sessions (S1-MME)"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/mme_session/gauge\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\""]
                      }
                    }
                  }
                }
              ]
              yAxis = { label = "Count", scale = "LINEAR" }
            }
          }
        },

        # Row 3: SMF Slicing/PDU Sessions, UPF N3 GTP-U Data Plane, PCF Policy Associations
        {
          xPos   = 0
          yPos   = 9
          width  = 4
          height = 4
          widget = {
            title = "SMF PDU Sessions & QoS Flows by Slice (:9090)"
            xyChart = {
              chartOptions = { mode = "COLOR" }
              dataSets = [
                {
                  plotType       = "LINE"
                  legendTemplate = "$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): PDU Sessions [SNSSAI=$${metric.labels.snssai}]"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/fivegs_smffunction_sm_sessionnbr/gauge\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\"", "metric.label.\"snssai\""]
                      }
                    }
                  }
                },
                {
                  plotType       = "LINE"
                  legendTemplate = "$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): QoS Flows [5QI=$${metric.labels.fiveqi}]"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/fivegs_smffunction_sm_qos_flow_nbr/gauge\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\"", "metric.label.\"fiveqi\""]
                      }
                    }
                  }
                },
                {
                  plotType       = "LINE"
                  legendTemplate = "$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): Active UEs"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/ues_active/gauge\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\""]
                      }
                    }
                  }
                }
              ]
              yAxis = { label = "Active Sessions / Flows", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 4
          yPos   = 9
          width  = 4
          height = 4
          widget = {
            title = "UPF N3 GTP-U Packet Rate & Active QoS Flows (:9090)"
            xyChart = {
              chartOptions = { mode = "COLOR" }
              dataSets = [
                {
                  plotType       = "LINE"
                  legendTemplate = "$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): N3 GTP-U Inbound Pkts/s (UL)"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/fivegs_ep_n3_gtp_indatapktn3upf/counter\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\""]
                      }
                    }
                  }
                },
                {
                  plotType       = "LINE"
                  legendTemplate = "$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): N3 GTP-U Outbound Pkts/s (DL)"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/fivegs_ep_n3_gtp_outdatapktn3upf/counter\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\""]
                      }
                    }
                  }
                },
                {
                  plotType       = "LINE"
                  legendTemplate = "$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): Active QoS Flows [DNN=$${metric.labels.dnn}]"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/fivegs_upffunction_upf_qosflows/gauge\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\"", "metric.label.\"dnn\""]
                      }
                    }
                  }
                }
              ]
              yAxis = { label = "Packets/s & Flows", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 8
          yPos   = 9
          width  = 4
          height = 4
          widget = {
            title = "PCF Policy Sessions & N4 PFCP Procedures (:9090)"
            xyChart = {
              chartOptions = { mode = "COLOR" }
              dataSets = [
                {
                  plotType       = "LINE"
                  legendTemplate = "Deployment/$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): Policy Sessions"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/fivegs_pcffunction_pa_sessionnbr/gauge\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\""]
                      }
                    }
                  }
                },
                {
                  plotType       = "LINE"
                  legendTemplate = "Deployment/$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): SM Policy Assoc/s"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/fivegs_pcffunction_pa_policysmassosucc/counter\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\""]
                      }
                    }
                  }
                },
                {
                  plotType       = "LINE"
                  legendTemplate = "StatefulSet/$${metric.labels.top_level_controller_name} ($${metric.labels.pod}): N4 Session Req/s"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/fivegs_upffunction_sm_n4sessionestabreq/counter\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.label.\"top_level_controller_name\"", "metric.label.\"pod\""]
                      }
                    }
                  }
                }
              ]
              yAxis = { label = "Sessions / Rate", scale = "LINEAR" }
            }
          }
        },

        # Row 4: Native Open5GS libogsmetrics Process Telemetry (:9090)
        {
          xPos   = 0
          yPos   = 13
          width  = 6
          height = 4
          widget = {
            title = "Open5GS NF Process Resident Memory (:9090 process_resident_memory_bytes)"
            xyChart = {
              chartOptions = { mode = "COLOR" }
              dataSets = [
                {
                  plotType       = "LINE"
                  legendTemplate = "$${metric.labels.top_level_controller_type}/$${metric.labels.top_level_controller_name}: $${metric.labels.pod} ($${metric.labels.container})"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND resource.label.\"job\"=\"open5gs-nf-metrics\" AND metric.type=\"prometheus.googleapis.com/process_resident_memory_bytes/gauge\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields = [
                          "metric.label.\"top_level_controller_type\"",
                          "metric.label.\"top_level_controller_name\"",
                          "metric.label.\"pod\"",
                          "metric.label.\"container\""
                        ]
                      }
                    }
                  }
                }
              ]
              yAxis = { label = "Bytes", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 6
          yPos   = 13
          width  = 6
          height = 4
          widget = {
            title = "Open5GS NF Open File Descriptors (:9090 process_open_fds)"
            xyChart = {
              chartOptions = { mode = "COLOR" }
              dataSets = [
                {
                  plotType       = "LINE"
                  legendTemplate = "$${metric.labels.top_level_controller_type}/$${metric.labels.top_level_controller_name}: $${metric.labels.pod} ($${metric.labels.container})"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND resource.label.\"job\"=\"open5gs-nf-metrics\" AND metric.type=\"prometheus.googleapis.com/process_open_fds/gauge\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields = [
                          "metric.label.\"top_level_controller_type\"",
                          "metric.label.\"top_level_controller_name\"",
                          "metric.label.\"pod\"",
                          "metric.label.\"container\""
                        ]
                      }
                    }
                  }
                }
              ]
              yAxis = { label = "Open FDs", scale = "LINEAR" }
            }
          }
        },

        # ----------------------------------------------------------------------
        # Banner 2: GKE Deployments, StatefulSets, Workloads & Cluster Metrics
        # ----------------------------------------------------------------------
        {
          xPos   = 0
          yPos   = 17
          width  = 12
          height = 2
          widget = {
            title = "GKE Deployments, StatefulSets & Cluster Health (open5gs-5gc-cluster)"
            text = {
              content = "Kubernetes **Deployment** & **StatefulSet** replica availability, per-workload CPU/Memory/Network consumption across all 17 Open5GS NFs (`NRF`, `SCP`, `UDR`, `UDM`, `AUSF`, `PCF`, `NSSF`, `BSF`, `SEPP`, `AMF`, `SMF`, `UPF`, `HSS`, `PCRF`, `MME`, `SGW-C`, `SGW-U`), **WebUI NMS**, **UERANSIM**, and GKE Control Plane API Server latency."
              format  = "MARKDOWN"
            }
          }
        },

        # Row 5: GKE Deployments & StatefulSets Replica Availability & Workload Running Pod Counts
        {
          xPos   = 0
          yPos   = 19
          width  = 6
          height = 4
          widget = {
            title = "GKE Deployments & StatefulSets Ready Replicas (open5gs Namespace)"
            xyChart = {
              chartOptions = { mode = "COLOR" }
              dataSets = [
                {
                  plotType       = "LINE"
                  legendTemplate = "Deployment/$${metric.labels.deployment}"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/kube_deployment_status_replicas_available/gauge\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_MAX"
                        groupByFields      = ["metric.label.\"deployment\""]
                      }
                    }
                  }
                },
                {
                  plotType       = "LINE"
                  legendTemplate = "StatefulSet/$${metric.labels.statefulset}"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND resource.label.\"namespace\"=\"open5gs\" AND metric.type=\"prometheus.googleapis.com/kube_statefulset_status_replicas_ready/gauge\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_MAX"
                        groupByFields      = ["metric.label.\"statefulset\""]
                      }
                    }
                  }
                }
              ]
              yAxis = { label = "Ready Replicas", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 6
          yPos   = 19
          width  = 6
          height = 4
          widget = {
            title = "GKE Active Running Containers by Deployment / StatefulSet"
            xyChart = {
              chartOptions = { mode = "COLOR" }
              dataSets = [
                {
                  plotType       = "STACKED_AREA"
                  legendTemplate = "$${metadata.system_labels\\.top_level_controller_type}/$${metadata.system_labels\\.top_level_controller_name}"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"open5gs\" AND metric.type=\"kubernetes.io/container/uptime\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_COUNT"
                        groupByFields = [
                          "metadata.system_labels.\"top_level_controller_type\"",
                          "metadata.system_labels.\"top_level_controller_name\""
                        ]
                      }
                    }
                  }
                }
              ]
              yAxis = { label = "Running Containers", scale = "LINEAR" }
            }
          }
        },

        # Row 6: GKE Deployment CPU, Memory, Pod Network & Container Restarts
        {
          xPos   = 0
          yPos   = 23
          width  = 4
          height = 4
          widget = {
            title = "GKE Deployment & Workload CPU Usage (Cores)"
            xyChart = {
              chartOptions = { mode = "COLOR" }
              dataSets = [
                {
                  plotType       = "LINE"
                  legendTemplate = "$${metadata.system_labels\\.top_level_controller_type}/$${metadata.system_labels\\.top_level_controller_name}"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"open5gs\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields = [
                          "metadata.system_labels.\"top_level_controller_type\"",
                          "metadata.system_labels.\"top_level_controller_name\""
                        ]
                      }
                    }
                  }
                }
              ]
              yAxis = { label = "CPU Cores", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 4
          yPos   = 23
          width  = 4
          height = 4
          widget = {
            title = "GKE Deployment & Workload Memory Usage (Bytes)"
            xyChart = {
              chartOptions = { mode = "COLOR" }
              dataSets = [
                {
                  plotType       = "LINE"
                  legendTemplate = "$${metadata.system_labels\\.top_level_controller_type}/$${metadata.system_labels\\.top_level_controller_name}"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"open5gs\" AND metric.type=\"kubernetes.io/container/memory/used_bytes\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields = [
                          "metadata.system_labels.\"top_level_controller_type\"",
                          "metadata.system_labels.\"top_level_controller_name\""
                        ]
                      }
                    }
                  }
                }
              ]
              yAxis = { label = "Memory Bytes", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 8
          yPos   = 23
          width  = 4
          height = 4
          widget = {
            title = "GKE Pod Network Throughput (RX / TX Bytes/s)"
            xyChart = {
              chartOptions = { mode = "COLOR" }
              dataSets = [
                {
                  plotType       = "LINE"
                  legendTemplate = "RX: $${metadata.system_labels\\.top_level_controller_type}/$${metadata.system_labels\\.top_level_controller_name}"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_pod\" AND resource.label.\"namespace_name\"=\"open5gs\" AND metric.type=\"kubernetes.io/pod/network/received_bytes_count\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields = [
                          "metadata.system_labels.\"top_level_controller_type\"",
                          "metadata.system_labels.\"top_level_controller_name\""
                        ]
                      }
                    }
                  }
                },
                {
                  plotType       = "LINE"
                  legendTemplate = "TX: $${metadata.system_labels\\.top_level_controller_type}/$${metadata.system_labels\\.top_level_controller_name}"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_pod\" AND resource.label.\"namespace_name\"=\"open5gs\" AND metric.type=\"kubernetes.io/pod/network/sent_bytes_count\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields = [
                          "metadata.system_labels.\"top_level_controller_type\"",
                          "metadata.system_labels.\"top_level_controller_name\""
                        ]
                      }
                    }
                  }
                }
              ]
              yAxis = { label = "Bytes / sec", scale = "LINEAR" }
            }
          }
        },

        # Row 7: Container Restart Stability, GKE API Server Latency (P99), & Node Pool Utilization
        {
          xPos   = 0
          yPos   = 27
          width  = 4
          height = 4
          widget = {
            title = "GKE Container Restart Rate by Deployment / StatefulSet"
            xyChart = {
              chartOptions = { mode = "COLOR" }
              dataSets = [
                {
                  plotType       = "LINE"
                  legendTemplate = "$${metadata.system_labels\\.top_level_controller_type}/$${metadata.system_labels\\.top_level_controller_name}"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"open5gs\" AND metric.type=\"kubernetes.io/container/restart_count\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_DELTA"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields = [
                          "metadata.system_labels.\"top_level_controller_type\"",
                          "metadata.system_labels.\"top_level_controller_name\""
                        ]
                      }
                    }
                  }
                }
              ]
              yAxis = { label = "Restarts / min", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 4
          yPos   = 27
          width  = 4
          height = 4
          widget = {
            title = "GKE Control Plane API Server Latency (P99)"
            xyChart = {
              chartOptions = { mode = "COLOR" }
              dataSets = [
                {
                  plotType       = "LINE"
                  legendTemplate = "kube-apiserver P99 ($${metric.labels.verb})"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"prometheus_target\" AND metric.type=\"prometheus.googleapis.com/apiserver_request_duration_seconds/histogram\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_DELTA"
                        crossSeriesReducer = "REDUCE_PERCENTILE_99"
                        groupByFields      = ["metric.label.\"verb\""]
                      }
                    }
                  }
                }
              ]
              yAxis = { label = "Seconds (P99)", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 8
          yPos   = 27
          width  = 4
          height = 4
          widget = {
            title = "GKE Node CPU & Memory Utilization (Control & Multi-NIC Pools)"
            xyChart = {
              chartOptions = { mode = "COLOR" }
              dataSets = [
                {
                  plotType       = "LINE"
                  legendTemplate = "CPU: $${resource.labels.node_name}"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_node\" AND resource.label.\"cluster_name\"=\"open5gs-5gc-cluster\" AND metric.type=\"kubernetes.io/node/cpu/allocatable_utilization\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields      = ["resource.label.\"node_name\""]
                      }
                    }
                  }
                },
                {
                  plotType       = "LINE"
                  legendTemplate = "Mem: $${resource.labels.node_name}"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_node\" AND resource.label.\"cluster_name\"=\"open5gs-5gc-cluster\" AND metric.type=\"kubernetes.io/node/memory/allocatable_utilization\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields      = ["resource.label.\"node_name\""]
                      }
                    }
                  }
                }
              ]
              yAxis = { label = "Utilization (0-1)", scale = "LINEAR" }
            }
          }
        }
      ]
    }
  })
}
