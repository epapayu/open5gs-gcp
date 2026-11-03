# Walkthrough: Live End-to-End Open5GS 5G SA & EPC Deployment on GCP

> [!IMPORTANT]
> **100% Live Deployment & End-to-End 5G SA Verification Complete** on Google Cloud (`us-central1`) and synced to [`epapayu/open5gs-gcp`](https://github.com/epapayu/open5gs-gcp).

---

## 1. Provisioned Google Cloud Infrastructure (`terraform/`)

All **25 Terraform resources** in [`terraform/main.tf`](terraform/main.tf), [`terraform/variables.tf`](terraform/variables.tf), and [`terraform/outputs.tf`](terraform/outputs.tf) were provisioned and verified end-to-end:

| Layer | GCP Resource | Live Configuration & Endpoint |
| :--- | :--- | :--- |
| **Multi-VPC Fabric** | `vpc-sbi-mgmt`, `vpc-n2-signaling`, `vpc-n3-userplane`, `vpc-n4-pfcp`, `vpc-n6-dn` | `MTU 8896` on `N3` & `N4`; Secondary Pod Alias Ranges (`pods-sbi`, `pods-n2`, `pods-n3`, `pods-n4`, `pods-n6`) |
| **Cloud NAT** | `open5gs-sbi-nat`, `open5gs-n6-nat` | Dedicated UE `N6` Internet breakout (`ALL_SUBNETWORKS_ALL_IP_RANGES`) |
| **3GPP Firewalls & WAF** | `allow-n2-s1mme-sctp`, `allow-n3-gtpu-udp`, `allow-n4-pfcp-udp`, `open5gs-nms-cloud-armor-policy` | `SCTP :38412/:36412/:29118`, `UDP :2123`, `UDP :2152`, `UDP :8805` + Cloud Armor WAF |
| **GKE Cluster** | `open5gs-5gc-cluster` (`v1.36.4-gke.2046003`, `us-central1`) | Dataplane V2 (`ADVANCED_DATAPATH`), `enable_multi_networking = true`, Private Nodes, Managed Prometheus |
| **Node Pools** | `sba-control-plane-pool` (`3x n2-standard-8`) & `upf-amf-multinic-pool` (`2x c3-standard-8`) | 5 `Ready` nodes; C3 pool equipped with `5x gVNIC` NICs (`ens3..ens7`) + secondary pod networks |
| **Subscriber & Policy DB** | Cloud Firestore Enterprise (`open5gs-db`, MongoDB-Compatible) | `<database-uid>.us-central1.firestore.goog:443` (SCRAM-SHA-256 + PITR) |
| **In-Memory Cache** | Cloud Memorystore Redis 7.2 HA (`open5gs-inmemory-cache`) | `STANDARD_HA` (`6378`, `SERVER_AUTHENTICATION`) |

---

## 2. Live GKE Multi-Networking & Complete 17-Daemon Open5GS Fleet (`k8s/`)

All **5 GKE L3 Multi-Networks** in [`k8s/00-namespace-and-networks.yaml`](k8s/00-namespace-and-networks.yaml) reconciled to `Ready = True` (`NetworkReady`):
- `default` (`vpc-sbi-mgmt` / `pods-sbi`)
- `n2-signaling-net` (`vpc-n2-signaling` / `pods-n2`)
- `n3-userplane-net` (`vpc-n3-userplane` / `pods-n3`, `MTU 8896`)
- `n4-pfcp-net` (`vpc-n4-pfcp` / `pods-n4`, `MTU 8896`)
- `n6-dn-net` (`vpc-n6-dn` / `pods-n6`)

All **17 Open5GS Daemons**, the **Cloud Firestore Wire-Protocol TLS Adapter**, **NMS WebUI**, and **UERANSIM Simulators** (`30/30` pods) ran `1/1 Running` in namespace `open5gs`:

- **5G SA SBA Control Plane** ([`k8s/01-control-plane-sba.yaml`](k8s/01-control-plane-sba.yaml)):
  - `open5gs-nrf` (`1/1`), `open5gs-scp` (`2/2`), `open5gs-udr` (`2/2`), `open5gs-udm` (`2/2`), `open5gs-ausf` (`2/2`), `open5gs-pcf` (`2/2`), `open5gs-nssf` (`2/2`), `open5gs-bsf` (`2/2`), `open5gs-sepp` (`2/2`), Multi-NIC `open5gs-amf-0` (`1/1`, `net1=10.120.0.2`), Multi-NIC `open5gs-smf-0` (`1/1`).
  - `open5gs-firestore-proxy` (`2/2`): Translates legacy `libmongoc` 1.17 & Mongoose v5 `OP_QUERY` handshakes to Cloud Firestore TLS `:443` `OP_MSG` (`hello: 1, loadBalanced: true`) while forwarding SCRAM-SHA-256 and BSON CRUD frames end-to-end.
- **Dedicated Multi-NIC User Plane** ([`k8s/02-upf-user-plane.yaml`](k8s/02-upf-user-plane.yaml)):
  - `open5gs-upf-0` (`1/1`): `eth0` telemetry, `net1=10.130.0.35` (`N3` GTP-U), `net2=10.140.0.35` (`N4` PFCP), `net3=10.160.0.35` (`N6` DN breakout), `ogstun` (`10.45.0.1/16`) policy-routed via table `200` out `net3` to `open5gs-n6-nat`.
- **NMS WebUI & GCE External ALB** ([`k8s/03-nms-webui-iap.yaml`](k8s/03-nms-webui-iap.yaml)):
  - `open5gs-webui` (`2/2` Ready) exposed via `open5gs-nms-ingress` (`HTTP 200`) protected by Cloud Armor policy `open5gs-nms-cloud-armor-policy`.
- **4G EPC CUPS & N26 Interworking** ([`k8s/05-epc-cups-and-interworking.yaml`](k8s/05-epc-cups-and-interworking.yaml)):
  - `open5gs-hss` (`1/1`), `open5gs-pcrf` (`1/1`), Multi-NIC `open5gs-mme-0` (`1/1`), Multi-NIC `open5gs-sgwc-0` (`1/1`), Multi-NIC `open5gs-sgwu-0` (`1/1`, `net2=10.140.0.4`), and `job/open5gs-dbctl-subscriber-seed` (`Complete 1/1`, seeded `IMSI 999700000000001`).

---

## 3. End-to-End 5G SA Control & User Plane Verification ([`k8s/04-ueransim-ran-ue-simulator.yaml`](k8s/04-ueransim-ran-ue-simulator.yaml))

### 3.1 3GPP TS 29.510 NRF NF-Discovery Conformance Job (`Complete 1/1`)
```text
Checking 3GPP TS 29.510 NRF NF-Discovery for SCP (requester=AMF)...   [OK]
Checking 3GPP TS 29.510 NRF NF-Discovery for UDR (requester=UDM)...   [OK]
Checking 3GPP TS 29.510 NRF NF-Discovery for UDM (requester=AMF)...   [OK]
Checking 3GPP TS 29.510 NRF NF-Discovery for AUSF (requester=AMF)...  [OK]
Checking 3GPP TS 29.510 NRF NF-Discovery for PCF (requester=AMF)...   [OK]
Checking 3GPP TS 29.510 NRF NF-Discovery for NSSF (requester=AMF)...  [OK]
Checking 3GPP TS 29.510 NRF NF-Discovery for BSF (requester=PCF)...   [OK]
Checking 3GPP TS 29.510 NRF NF-Discovery for SEPP (requester=AMF)...  [OK]
Checking 3GPP TS 29.510 NRF NF-Discovery for AMF (requester=AMF)...   [OK]
Checking 3GPP TS 29.510 NRF NF-Discovery for SMF (requester=AMF)...   [OK]
All 3GPP 5G SA SBA Network Functions verified in NRF!
```

### 3.2 NGAP SCTP Setup, 5G-AKA Registration, & PDU Session (`uesimtun0`)
```text
# ueransim-gnb (Multi-NIC N2=10.120.0.4 -> AMF=10.120.0.2:38412, N3=10.130.0.3)
[sctp] [info] SCTP connection established (10.120.0.2:38412)
[ngap] [info] NG Setup procedure is successful
[ngap] [info] PDU session resource(s) setup for UE[1] count[1]

# ueransim-ue (IMSI 999700000000001, SST=1, SD=0x010203, DNN=internet)
[nas] [info] Initial Registration is successful
[nas] [info] PDU Session establishment is successful PSI[1]
[app] [info] Connection setup for PDU session[1] is successful, TUN interface[uesimtun0, 10.45.0.3] is up.
```

### 3.3 Live UE GTP-U User Plane Breakout (`uesimtun0` -> `N3` GTP-U -> UPF `ogstun` -> `N6` Cloud NAT)
```text
$ kubectl -n open5gs exec deploy/ueransim-ue -- ping -I uesimtun0 -c 4 8.8.8.8
PING 8.8.8.8 (8.8.8.8) from 10.45.0.3 uesimtun0: 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=113 time=2.71 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=113 time=1.89 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=113 time=1.70 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=113 time=1.92 ms
--- 8.8.8.8 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
rtt min/avg/max/mdev = 1.700/2.054/2.712/0.388 ms

$ kubectl -n open5gs exec deploy/ueransim-ue -- curl -sS --interface uesimtun0 -I https://www.google.com
HTTP/2 200
content-type: text/html; charset=ISO-8859-1
server: gws
```

### 3.4 Prometheus Telemetry (`:9090/metrics`), Google Cloud Monitoring Dashboard (`"Open5GS"`), & NMS WebUI Ingress
- **Google Cloud Monitoring Dashboard (`"Open5GS"`)** ([`terraform/monitoring_dashboard.tf`](terraform/monitoring_dashboard.tf)):
  - Provisioned via `google_monitoring_dashboard.open5gs_dashboard` (`displayName = "Open5GS"`, 19 widgets across a 12-column `mosaicLayout`).
  - **Open5GS `:9090/metrics` Section (Google Cloud Managed Service for Prometheus)**:
    - 4 real-time executive scorecards (`Connected 5G gNodeBs`, `Active AMF UE Sessions`, `Active SMF PDU Sessions`, `Active UPF User Plane Sessions`).
    - `:9090` scrape target health (`up`), AMF 5G-AKA registration & authentication rates, AMF/MME registered UEs & RAN peers, SMF PDU sessions & QoS flows by S-NSSAI/5QI, UPF `N3` GTP-U uplink/downlink packet rates & active QoS flows by DNN, PCF policy associations & `N4` PFCP session procedures, and native `libogsmetrics` NF process resident memory (`process_resident_memory_bytes`) & open file descriptors (`process_open_fds`).
  - **GKE Deployments, StatefulSets & Cluster Health Section (`open5gs-5gc-cluster`)**:
    - Enabled GKE monitoring components `SYSTEM_COMPONENTS`, `APISERVER`, `SCHEDULER`, `CONTROLLER_MANAGER`, `STORAGE`, `HPA`, `POD`, `DAEMONSET`, `DEPLOYMENT`, `STATEFULSET`, `KUBELET`, and `CADVISOR`.
    - Tracks `kube_deployment_status_replicas_available` + `kube_statefulset_status_replicas_ready` across all 20 Open5GS/NMS/UERANSIM workloads in namespace `open5gs`, active running containers (`kubernetes.io/container/uptime`), per-Deployment/StatefulSet CPU cores, memory bytes, pod `RX`/`TX` network throughput, container restart rate, **GKE Control Plane API Server P99 latency** (`apiserver_request_duration_seconds`), and node CPU/memory allocatable utilization across `sba-control-plane-pool` and `upf-amf-multinic-pool`.
- **AMF Metrics**: `gnb 1`, `amf_session 1`
- **SMF Metrics**: `ues_active 1`, `fivegs_smffunction_sm_sessionnbr{plmnid="99970",snssai="1-010203"} 1`, `fivegs_smffunction_sm_qos_flow_nbr{plmnid="99970",snssai="1-010203",fiveqi="9"} 1`
- **UPF Metrics**: `fivegs_upffunction_sm_n4sessionestabreq 1`, `fivegs_upffunction_upf_sessionnbr 1`, `fivegs_upffunction_upf_qosflows{dnn="internet"} 1`
- **NMS WebUI External ALB**: `HTTP 200` on GCE External Application Load Balancer + Cloud Armor WAF

---

## 4. Key Engineering Findings & Remediations Applied

1. **Open5GS v2.7.2 `epoll_create()` Pool Initialization**: Open5GS v2.7.2 `libogsapp` requires an explicit top-level `global: { max: { ue: 1024 } }` block in each NF YAML configuration so `ogs_app_parse_global_conf()` invokes `recalculate_pool_size()` (`self.max.poll = ue * 16`). Added across all 17 NF configs.
2. **GKE Dataplane V2 L3 Multi-Networking**: Configured `secondary_ip_range` blocks (`pods-n2`, `pods-n3`, `pods-n4`, `pods-n6`), `additional_pod_network_configs` on `upf-amf-multinic-pool`, `podIPv4Ranges` in each `GKENetworkParamSet`, and `networking.gke.io/default-interface: "eth0"` on all Multi-NIC pods (`amf`, `smf`, `upf`, `mme`, `sgwc`, `sgwu`, `ueransim-gnb`).
3. **Cloud Firestore MongoDB Wire-Protocol Compatibility**: Deployed `open5gs-firestore-proxy` to adapt legacy `libmongoc` (<1.20) and Mongoose v5 `OP_QUERY` handshakes to Cloud Firestore's `OP_MSG` (`hello: 1, loadBalanced: true`) over TLS `:443` with `retryWrites=false`.
4. **3GPP TS 29.510 NRF NF-Discovery Authorization**: Configured `open5gs-native-5gc-conformance-test` to query `nnrf-disc` using authorized `requester-nf-type` roles (`UDM` for `UDR`, `PCF` for `BSF`, `AMF` for SBA peers).
5. **Open5GS v2.7.2 `:9090/metrics` Target Scoping**: Removed `metrics: enabled` from `open5gs-pcrf` (as `open5gs-pcrfd` v2.7.2 does not bind `libogsmetrics` `:9090`) and scoped `up/gauge` and `process_*` queries to `resource.label."job"="open5gs-nf-metrics"` so all 6 active Open5GS Prometheus targets (`amf`, `smf`, `upf`, `pcf` x2, `mme`) report `up = 1` cleanly without mixing `kube-state-metrics` targets.
6. **Google Cloud Monitoring `legendTemplate` Label Resolution**: Configured plural `${metric.labels.<key>}` and `${resource.labels.<key>}` paths along with escaped-dot system metadata keys (`${metadata.system_labels\.top_level_controller_type}/${metadata.system_labels\.top_level_controller_name}`) across all 13 `xyChart` widgets in [`terraform/monitoring_dashboard.tf`](terraform/monitoring_dashboard.tf), ensuring every series displays meaningful `Deployment/<name>`, `StatefulSet/<name>`, pod, container, slice/DNN, and node names rather than empty strings or series UUIDs.
