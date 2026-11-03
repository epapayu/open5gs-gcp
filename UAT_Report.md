# Open5GS 5G SA + 4G EPC CUPS on Google Cloud — User Acceptance Testing (UAT) Report

| Metadata Field | Value |
| :--- | :--- |
| **Document Title** | User Acceptance Testing (UAT) Report & Standard Operating Procedures |
| **GCP Project ID** | `open5gs-513602` (`us-central1`) |
| **GKE Cluster** | `open5gs-5gc-cluster` (Regional `us-central1-a/b/c`, Dataplane V2 + Multi-NIC `gvnic`) |
| **Kubernetes Namespace** | `open5gs` |
| **Open5GS Version** | `v2.7.2` (`gradiant/open5gs:2.7.2`, `gradiant/open5gs-webui:2.7.2`, `gradiant/ueransim:3.2.6`) |
| **Subscriber Data Tier** | Cloud Firestore Enterprise (MongoDB Compatibility API, `us-central1`) via `open5gs-firestore-proxy` |
| **NMS WebUI Ingress** | `ingress/open5gs-nms-ingress` (GCE External Application Load Balancer + Cloud Armor WAF + Cookie Affinity) |
| **Cloud Monitoring Dashboard** | `"Open5GS"` Custom Dashboard (Google Cloud Monitoring + Managed Service for Prometheus) |
| **Test Execution Timestamp** | `2026-11-03 07:42 UTC` |
| **Overall UAT Status** | **PASS (`21 / 21` Workloads Verified + E2E 5G UE Speedtest: `623.87 Mbps` DL / `329.09 Mbps` UL / `1.93 ms` RTT)** |

---

## Table of Contents

1. [Cloud Monitoring "Open5GS" Dashboard Snapshots](#1-cloud-monitoring-open5gs-dashboard-snapshots)
2. [Open5GS NMS WebUI & UE Subscriber Profile Snapshot](#2-open5gs-nms-webui--ue-subscriber-profile-snapshot)
3. [Functional Test Results for All Deployments & StatefulSets (`21/21`)](#3-functional-test-results-for-all-deployments--statefulsets-2121)
   - [3.22 End-to-End 5G User-Plane Speedtest (Simulated UE)](#322-end-to-end-5g-user-plane-speedtest-simulated-ue)
4. [Step-by-Step Test Execution Procedures (SOP)](#4-step-by-step-test-execution-procedures-sop)
   - [4.1 Procedure for Item 2: Registering the UE Subscriber Profile in NMS WebUI & Attaching the UE](#41-procedure-for-item-2-registering-the-ue-subscriber-profile-in-nms-webui--attaching-the-ue)
   - [4.2 Procedure for Item 3: Executing Functional Tests Across All Deployments & StatefulSets](#42-procedure-for-item-3-executing-functional-tests-across-all-deployments--statefulsets)
   - [4.3 Procedure for Executing the End-to-End 5G UE Speedtest](#43-procedure-for-executing-the-end-to-end-5g-ue-speedtest)

---

## 1. Cloud Monitoring "Open5GS" Dashboard Snapshots

The unified **"Open5GS"** Google Cloud Monitoring dashboard aggregates **Google Cloud Managed Service for Prometheus (GMP)** `:9090/metrics` 3GPP telemetry (`PodMonitoring/open5gs-nf-metrics` at a `15s` scrape interval) together with **GKE Deployment, StatefulSet, Pod Network, API Server, and Multi-NIC Node Pool** metrics in a single view.

- **Infrastructure-as-Code Definition**: [`terraform/monitoring_dashboard.tf`](terraform/monitoring_dashboard.tf)

### 1.1 Part 1 — Executive Scorecards & Open5GS Prometheus Telemetry (`:9090/metrics`)

![Open5GS Cloud Monitoring Dashboard — Part 1: Scorecards & Prometheus :9090/metrics](assets/cloud_monitoring_open5gs_prometheus.jpg)

### 1.2 Part 2 — GKE Deployments, StatefulSets & Multi-NIC Infrastructure Metrics

![Open5GS Cloud Monitoring Dashboard — Part 2: GKE Deployments, StatefulSets & Node Pools](assets/cloud_monitoring_open5gs_gke_workloads.jpg)

### 1.3 Verified Dashboard KPI Summary

| Dashboard Section | Widget / Metric | Observed Live Value | Status |
| :--- | :--- | :--- | :---: |
| **Scorecards** | Connected 5G gNodeBs (N2 SCTP) (`gnb`) | `1` (`ueransim-gnb` over N2 SCTP `10.120.0.4 -> 10.120.0.2:38412`) | PASS |
| **Scorecards** | Active AMF UE Sessions (`amf_session` / `ran_ue`) | `1` (`imsi-999700000000001`, `CM-CONNECTED` / `RM-REGISTERED`) | PASS |
| **Scorecards** | Active SMF PDU Sessions (S-NSSAI) (`ues_active`) | `1` (`PDU Session 1` on `DNN=internet`, `10.45.0.3`) | PASS |
| **Scorecards** | Active UPF User Plane Sessions (N4) (`fivegs_upffunction_upf_sessionnbr`) | `1` (`ogstun` `10.45.0.1/16`, `5QI=9`) | PASS |
| **3GPP `:9090` Telemetry** | AMF 5G-AKA Registration & Auth Procedures (`:9090`) | `100%` 5G-AKA registration & authentication success | PASS |
| **3GPP `:9090` Telemetry** | SMF PDU Sessions & QoS Flows by Slice (`:9090`) | `1` session (`plmnid=99970, snssai=1-010203`), `2` QoS flows (`5QI=9`) | PASS |
| **3GPP `:9090` Telemetry** | PCF Policy Sessions & N4 PFCP Procedures (`:9090`) | `1` active policy session (`2` AM + `2` SM policy associations) | PASS |
| **NF `:9090` Health** | Prometheus `:9090` Scrape Target Health (`up`) | `1.0` (`100%` healthy across `amf`, `smf`, `upf`, `pcf`, `mme`) | PASS |
| **GKE Workloads** | GKE Deployments & StatefulSets Ready Replicas (`open5gs`) | All `15` Deployments and `6` StatefulSets at `100%` desired availability | PASS |
| **GKE Stability** | GKE Container Restart Rate (`restart_count`) | `0.00 restarts/min` across steady-state test window | PASS |

---

## 2. Open5GS NMS WebUI & UE Subscriber Profile Snapshot

The Open5GS NMS WebUI (`gradiant/open5gs-webui:2.7.2`) is exposed via Google Cloud External Application Load Balancer (`ingress/open5gs-nms-ingress`) protected by Cloud Armor WAF (`open5gs-nms-armor-policy`), `GENERATED_COOKIE` session affinity, and backed by **Cloud Firestore Enterprise (MongoDB Compatibility API)** through `open5gs-firestore-proxy`.

### 2.1 NMS WebUI Subscriber Registry List View

![Open5GS NMS WebUI — Registered Subscriber List](assets/nms_webui_subscribers.png)

### 2.2 NMS WebUI UE Subscriber Profile Detail View (`IMSI 999700000000001`)

![Open5GS NMS WebUI — UE Subscriber Profile Configuration Details](assets/nms_webui_ue_profile.png)

### 2.3 Provisioned UE Test Profile Specification (`IMSI 999700000000001`)

The table below documents every 3GPP USIM authentication, slice (S-NSSAI), DNN, QoS, and AMBR parameter provisioned in the NMS WebUI and verified during the UAT run:

| Category | Parameter | Provisioned Value | 3GPP / Test Purpose |
| :--- | :--- | :--- | :--- |
| **Identity** | **IMSI (SUPI)** | `999700000000001` | PLMN `MCC=999`, `MNC=70`, MSIN `0000000001` |
| **Equipment** | **IMEISV** | `4370816125816151` | Simulated 5G SA UE software version identity (`ueransim-ue`) |
| **5G-AKA Security** | **Subscriber Key (`K`)** | `465B5CE8B199B49FAA5F0A2EE238A6BC` | 128-bit permanent USIM Milenage secret key (3GPP test vector) |
| **5G-AKA Security** | **Operator Key (`OPc`)** | `E8ED289DEBA952E4283B54E88E6183CA` | 128-bit derived operator variant algorithm configuration field |
| **5G-AKA Security** | **AMF (Auth Mgmt Field)** | `8000` | Standard 5G-AKA authentication management field |
| **5G-AKA Security** | **SQN (Sequence Number)** | `129` (`0x000000000081`) | Incremented automatically by `UDR`/`AUSF` upon 5G-AKA auth |
| **Subscription** | **Subscriber Status** | `SERVICE_GRANTED (0)` | Full 5GS / EPS packet service permitted |
| **Subscription** | **Network Access Mode** | `PACKET_AND_CIRCUIT (0)` | Dual 5G SA + 4G EPC packet data access |
| **Aggregate Rate** | **Subscribed UE-AMBR (DL / UL)** | `1000000000 bps` / `1000000000 bps` (`1 Gbps`) | Enforced by `UDM` (`nudm-sdm`) and `AMF` |
| **Network Slice** | **S-NSSAI (`SST` / `SD`)** | `SST: 1` (eMBB), `SD: 010203` *(Default S-NSSAI)* | Validated by `AMF`, `NSSF`, `SMF`, and `PCF` |
| **Session / APN** | **DNN / APN** | `internet` | Routed to UPF subnet `10.45.0.0/16` (`ogstun` -> `vpc-n6` Cloud NAT) |
| **Session / APN** | **PDN / PDU Session Type** | `IPv4v6` (negotiated `IPv4` `10.45.0.3`) | Allocated dynamically by `SMF` / `UPF` |
| **QoS Profile** | **Default 5QI / QCI** | `9` | Non-GBR best-effort data bearer |
| **QoS Profile** | **ARP Priority / Pre-emption** | `Priority Level: 8` (`Disabled` / `Disabled`) | Allocation and Retention Priority |
| **Session Rate** | **Session-AMBR (DL / UL)** | `1000000000 bps` / `1000000000 bps` (`1 Gbps`) | Enforced on `PDU Session 1` (`up[1000000Kb/s] down[1000000Kb/s]`) |

---

## 3. Functional Test Results for All Deployments & StatefulSets (`21/21`)

Every Kubernetes `Deployment` (`15`) and `StatefulSet` (`6`) in namespace `open5gs` was functionally tested against its live 3GPP interface (HTTP/2 Service-Based Architecture `:7777`, NGAP/S1AP SCTP, N3/S1-U GTP-U, N4/Sxa PFCP, Diameter S6a/Gx, MongoDB-to-Firestore wire proxy, NMS WebUI service `:9999`, and Prometheus `:9090/metrics`).

### 3.0 Master Test Execution Matrix

| # | Kind | Workload Name | 3GPP / Platform Role | Primary Verification Method | Result |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **01** | `Deployment` | `open5gs-nrf` | NF Repository Function (`nnrf-nfm` / `nnrf-disc`) | HTTP/2 SBI query of registered NF instances | **PASS** |
| **02** | `Deployment` | `open5gs-scp` | Service Communication Proxy (`2` HA replicas) | `nnrf-disc` discovery verifying `2` `REGISTERED` SCP endpoints | **PASS** |
| **03** | `Deployment` | `open5gs-udr` | Unified Data Repository (Firestore-backed) | HTTP/2 `nudr-dr` query of `imsi-999700000000001` auth vector | **PASS** |
| **04** | `Deployment` | `open5gs-udm` | Unified Data Management (`nudm-sdm` / `nudm-ueau`) | HTTP/2 `nudm-sdm` AM-data retrieval (`1 Gbps` AMBR, `SST=1/010203`) | **PASS** |
| **05** | `Deployment` | `open5gs-ausf` | Authentication Server Function (`nausf-auth`) | `nnrf-disc` discovery of `2` active `nausf-auth` instances | **PASS** |
| **06** | `Deployment` | `open5gs-pcf` | Policy Control Function (`npcf-am` / `npcf-smpolicy`) | Live `:9090/metrics` check of active AM & SM policy associations | **PASS** |
| **07** | `Deployment` | `open5gs-nssf` | Network Slice Selection Function (`nnssf-nsselection`) | HTTP/2 `nnssf-nsselection` PDU session slice query (`SST=1, SD=010203`) | **PASS** |
| **08** | `Deployment` | `open5gs-bsf` | Binding Support Function (`nbsf-management`) | `nnrf-disc` discovery verifying `2` active `nbsf-management` pods | **PASS** |
| **09** | `Deployment` | `open5gs-sepp` | Security Edge Protection Proxy (`N32c` / `N32f`) | `nnrf-disc` discovery verifying `2` active `SEPP` roaming proxies | **PASS** |
| **10** | `Deployment` | `open5gs-hss` | 4G Home Subscriber Server (`Diameter S6a`) | Firestore DB init + `Diameter S6a` peer handshake with `mme.gradiant` | **PASS** |
| **11** | `Deployment` | `open5gs-pcrf` | 4G Policy & Charging Rules Function (`Diameter Gx`) | Firestore DB init + `Diameter Gx` peer handshake with `smf.gradiant` | **PASS** |
| **12** | `Deployment` | `open5gs-firestore-proxy` | MongoDB Wire-Protocol -> Cloud Firestore TLS Adapter | Readiness (`2/2`) + live TLS upstream tunnel to `us-central1.firestore.goog:443` | **PASS** |
| **13** | `Deployment` | `open5gs-webui` | Subscriber NMS WebUI + GCE ALB + Cloud Armor | Service `open5gs-webui-svc:9999` HTTP `200 OK` + `connect.sid` cookie | **PASS** |
| **14** | `Deployment` | `ueransim-gnb` | Multi-NIC 5G gNodeB Simulator (`N2` + `N3`) | `net1`/`net2` IP verification + `nr-cli` `is-ngap-up: true` | **PASS** |
| **15** | `Deployment` | `ueransim-ue` | 5G SA UE Simulator (`IMSI 999700000000001`) | `RM-REGISTERED`, `PS-ACTIVE` (`10.45.0.3`), `0%` loss ICMP + `HTTP/2 200` | **PASS** |
| **16** | `StatefulSet` | `open5gs-amf` | Multi-NIC 5G Access & Mobility Management (`N1`/`N2`) | `net1` (`10.120.0.2`) + `:9090` (`gnb=1`, `ran_ue=1`, `amf_session=1`) | **PASS** |
| **17** | `StatefulSet` | `open5gs-smf` | Multi-NIC 5G Session Management / PGW-C (`N4`/`S5c`) | `net1` (`10.140.0.5`) + `:9090` (`ues_active=1`, `sessionnbr=1`, `qos_flow=2`) | **PASS** |
| **18** | `StatefulSet` | `open5gs-upf` | Dedicated Multi-NIC User Plane Function (`N3`/`N4`/`N6`) | `net1..3` + `ogstun` (`146 RX / 169 TX pkts`, `0` drops) + `:9090` (`sessionnbr=1`) | **PASS** |
| **19** | `StatefulSet` | `open5gs-mme` | Multi-NIC 4G MME (`S1-MME` / `S11` / `S6a`) | `net1` (`10.120.0.3:36412`), `S11` GTP-C (`10.100.3.8:2123`), `S6a` Diameter up | **PASS** |
| **20** | `StatefulSet` | `open5gs-sgwc` | Multi-NIC 4G SGW Control Plane (`S11` / `Sxa`) | `net1` (`10.140.0.6:8805`) + active `Sxa` PFCP association with `SGW-U` | **PASS** |
| **21** | `StatefulSet` | `open5gs-sgwu` | Multi-NIC 4G SGW User Plane (`S1-U` / `Sxa`) | `net1` (`10.130.0.2:2152`), `net2` (`10.140.0.4:8805`) + PFCP associated | **PASS** |

---

### 3.1 Deployment `01/15`: `open5gs-nrf` (NF Repository Function — 3GPP TS 29.510)

- **Command**:
  ```bash
  kubectl -n open5gs get deploy/open5gs-nrf -o wide && \
  kubectl -n open5gs exec deploy/open5gs-scp -- curl -sS --http2-prior-knowledge \
    'http://open5gs-nrf.open5gs.svc.cluster.local:7777/nnrf-nfm/v1/nf-instances' | head -c 700; echo
  ```
- **Response Printout**:
  ```text
  NAME          READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                             SELECTOR
  open5gs-nrf   1/1     1            1           87m   nrfd         docker.io/gradiant/open5gs:2.7.2   nf=nrf
  {"_links":{"items":[{"href":"http://10.100.2.11:7777/nnrf-nfm/v1/nf-instances/71d0abe6-d738-41f1-9bb7-13a3ce97e89d"},{"href":"http://10.100.2.11:7777/nnrf-nfm/v1/nf-instances/73a394b0-d738-41f1-9bc8-89c6fee9020a"},{"href":"http://10.100.2.11:7777/nnrf-nfm/v1/nf-instances/73c6171a-d738-41f1-8184-d916d324b9b8"},{"href":"http://10.100.2.11:7777/nnrf-nfm/v1/nf-instances/73c5cff8-d738-41f1-b7da-b14f439fcdac"},{"href":"http://10.100.2.11:7777/nnrf-nfm/v1/nf-instances/73db05c6-d738-41f1-a22a-5d32bee01432"},{"href":"http://10.100.2.11:7777/nnrf-nfm/v1/nf-instances/6fbab64e-d738-41f1-bb20-25db84f6b881"},{"href":"http://10.100.2.11:7777/nnrf-nfm/v1/nf-instances/701604e0-d738-41f1-8000-7d41e35e6ddd"},{
  ```

### 3.2 Deployment `02/15`: `open5gs-scp` (Service Communication Proxy — Indirect SBA Mesh)

- **Command**:
  ```bash
  kubectl -n open5gs get deploy/open5gs-scp -o wide && \
  kubectl -n open5gs exec open5gs-amf-0 -- curl -sS --http2-prior-knowledge \
    'http://open5gs-nrf.open5gs.svc.cluster.local:7777/nnrf-disc/v1/nf-instances?target-nf-type=SCP&requester-nf-type=AMF'
  ```
- **Response Printout**:
  ```text
  NAME          READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                             SELECTOR
  open5gs-scp   2/2     2            2           87m   scpd         docker.io/gradiant/open5gs:2.7.2   nf=scp
  {"validityPeriod":30,"nfInstances":[{"nfInstanceId":"73c5cff8-d738-41f1-b7da-b14f439fcdac","nfType":"SCP","nfStatus":"REGISTERED","heartBeatTimer":10,"plmnList":[{"mcc":"999","mnc":"70"}],"ipv4Addresses":["10.100.1.34"],"priority":0,"capacity":100,"load":0,"nfProfileChangesSupportInd":true,"scpInfo":{"scpPorts":{"http":7777}}},{"nfInstanceId":"71da02f4-d738-41f1-b389-a34990adf57f","nfType":"SCP","nfStatus":"REGISTERED","heartBeatTimer":10,"plmnList":[{"mcc":"999","mnc":"70"}],"ipv4Addresses":["10.100.2.14"],"priority":0,"capacity":100,"load":0,"nfProfileChangesSupportInd":true,"scpInfo":{"scpPorts":{"http":7777}}}]}
  ```

### 3.3 Deployment `03/15`: `open5gs-udr` (Unified Data Repository — 3GPP TS 29.504 `nudr-dr`)

- **Command**:
  ```bash
  kubectl -n open5gs get deploy/open5gs-udr -o wide && \
  kubectl -n open5gs exec deploy/open5gs-udm -- curl -sS --http2-prior-knowledge \
    'http://open5gs-udr.open5gs.svc.cluster.local:7777/nudr-dr/v1/subscription-data/imsi-999700000000001/authentication-data/authentication-subscription'
  ```
- **Response Printout**:
  ```text
  NAME          READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                             SELECTOR
  open5gs-udr   2/2     2            2           87m   udrd         docker.io/gradiant/open5gs:2.7.2   nf=udr
  {"authenticationMethod":"5G_AKA","encPermanentKey":"465b5ce8b199b49faa5f0a2ee238a6bc","sequenceNumber":{"sqn":"000000000081"},"authenticationManagementField":"8000","encOpcKey":"e8ed289deba952e4283b54e88e6183ca"}
  ```

### 3.4 Deployment `04/15`: `open5gs-udm` (Unified Data Management — 3GPP TS 29.503 `nudm-sdm`)

- **Command**:
  ```bash
  kubectl -n open5gs get deploy/open5gs-udm -o wide && \
  kubectl -n open5gs exec deploy/open5gs-ausf -- curl -sS --http2-prior-knowledge \
    'http://open5gs-udm.open5gs.svc.cluster.local:7777/nudm-sdm/v2/imsi-999700000000001/am-data?plmn-id=%7B%22mcc%22%3A%22999%22%2C%22mnc%22%3A%2270%22%7D'
  ```
- **Response Printout**:
  ```text
  NAME          READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                             SELECTOR
  open5gs-udm   2/2     2            2           87m   udmd         docker.io/gradiant/open5gs:2.7.2   nf=udm
  {"subscribedUeAmbr":{"uplink":"1000000 Kbps","downlink":"1000000 Kbps"},"nssai":{"defaultSingleNssais":[{"sst":1,"sd":"010203"}]}}
  ```

### 3.5 Deployment `05/15`: `open5gs-ausf` (Authentication Server Function — 3GPP TS 29.509 `nausf-auth`)

- **Command**:
  ```bash
  kubectl -n open5gs get deploy/open5gs-ausf -o wide && \
  kubectl -n open5gs exec open5gs-amf-0 -- curl -sS --http2-prior-knowledge \
    'http://open5gs-nrf.open5gs.svc.cluster.local:7777/nnrf-disc/v1/nf-instances?target-nf-type=AUSF&requester-nf-type=AMF'
  ```
- **Response Printout**:
  ```text
  NAME           READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                             SELECTOR
  open5gs-ausf   2/2     2            2           87m   ausfd        docker.io/gradiant/open5gs:2.7.2   nf=ausf
  {"validityPeriod":30,"nfInstances":[{"nfInstanceId":"6fbab64e-d738-41f1-bb20-25db84f6b881","nfType":"AUSF","nfStatus":"REGISTERED","heartBeatTimer":10,"plmnList":[{"mcc":"999","mnc":"70"}],"ipv4Addresses":["10.100.2.7"],"allowedNfTypes":["SCP","AMF"],"priority":0,"capacity":100,"load":0,"nfServices":[{"serviceInstanceId":"6fbac0bc-d738-41f1-bb20-25db84f6b881","serviceName":"nausf-auth","versions":[{"apiVersionInUri":"v1","apiFullVersion":"1.0.0"}],"scheme":"http","nfServiceStatus":"REGISTERED","ipEndPoints":[{"ipv4Address":"10.100.2.7","port":7777}],"allowedNfTypes":["AMF"],"priority":0,"capacity":100,"load":0}],"nfProfileChangesSupportInd":true},{"nfInstanceId":"70638742-d738-41f1-968c-83e312a931fc","nfType":"AUSF","nfStatus":"REGISTERED","heartBeatTimer":10,"plmnList":[{"mcc":"999","mnc":"70"}],"ipv4Addresses":["10.100.1.30"],"allowedNfTypes":["SCP","AMF"],"priority":0,"capacity":100,"load":0,"nfServices":[{"serviceInstanceId":"70639318-d738-41f1-968c-83e312a931fc","serviceName":"nausf-auth","versions":[{"apiVersionInUri":"v1","apiFullVersion":"1.0.0"}],"scheme":"http","nfServiceStatus":"REGISTERED","ipEndPoints":[{"ipv4Address":"10.100.1.30","port":7777}],"allowedNfTypes":["AMF"],"priority":0,"capacity":100,"load":0}],"nfProfileChangesSupportInd":true}]}
  ```

### 3.6 Deployment `06/15`: `open5gs-pcf` (Policy Control Function — 3GPP TS 29.507 / TS 29.512 + `:9090`)

- **Command**:
  ```bash
  kubectl -n open5gs get deploy/open5gs-pcf -o wide && \
  kubectl -n open5gs exec deploy/open5gs-pcf -- sh -c \
    'curl -sS http://$(hostname -i):9090/metrics | grep -E "^(fivegs_pcffunction_pa_sessionnbr|fivegs_pcffunction_pa_policysmassosucc|fivegs_pcffunction_pa_policyamassosucc)"'
  ```
- **Response Printout**:
  ```text
  NAME          READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                             SELECTOR
  open5gs-pcf   2/2     2            2           87m   pcfd         docker.io/gradiant/open5gs:2.7.2   nf=pcf
  fivegs_pcffunction_pa_policyamassosucc{plmnid="99970",snssai="1-010203"} 2
  fivegs_pcffunction_pa_policysmassosucc{plmnid="99970",snssai="1-010203"} 2
  fivegs_pcffunction_pa_sessionnbr{plmnid="99970",snssai="1-010203"} 1
  ```

### 3.7 Deployment `07/15`: `open5gs-nssf` (Network Slice Selection Function — 3GPP TS 29.531 `nnssf-nsselection`)

- **Command**:
  ```bash
  kubectl -n open5gs get deploy/open5gs-nssf -o wide && \
  kubectl -n open5gs exec open5gs-amf-0 -- curl -sS --http2-prior-knowledge \
    'http://open5gs-nssf.open5gs.svc.cluster.local:7777/nnssf-nsselection/v2/network-slice-information?nf-type=AMF&nf-id=00000000-0000-4000-8000-000000000001&slice-info-request-for-pdu-session=%7B%22sNssai%22%3A%7B%22sst%22%3A1%2C%22sd%22%3A%22010203%22%7D%2C%22roamingIndication%22%3A%22NON_ROAMING%22%7D'
  ```
- **Response Printout**:
  ```text
  NAME           READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                             SELECTOR
  open5gs-nssf   2/2     2            2           87m   nssfd        docker.io/gradiant/open5gs:2.7.2   nf=nssf
  {"nsiInformation":{"nrfId":"http://open5gs-nrf.open5gs.svc.cluster.local:7777/nnrf-disc/v1/nf-instances","nsiId":"1"}}
  ```

### 3.8 Deployment `08/15`: `open5gs-bsf` (Binding Support Function — 3GPP TS 29.521 `nbsf-management`)

- **Command**:
  ```bash
  kubectl -n open5gs get deploy/open5gs-bsf -o wide && \
  kubectl -n open5gs exec deploy/open5gs-pcf -- curl -sS --http2-prior-knowledge \
    'http://open5gs-nrf.open5gs.svc.cluster.local:7777/nnrf-disc/v1/nf-instances?target-nf-type=BSF&requester-nf-type=PCF'
  ```
- **Response Printout**:
  ```text
  NAME          READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                             SELECTOR
  open5gs-bsf   2/2     2            2           87m   bsfd         docker.io/gradiant/open5gs:2.7.2   nf=bsf
  {"validityPeriod":30,"nfInstances":[{"nfInstanceId":"701604e0-d738-41f1-8000-7d41e35e6ddd","nfType":"BSF","nfStatus":"REGISTERED","heartBeatTimer":10,"plmnList":[{"mcc":"999","mnc":"70"}],"ipv4Addresses":["10.100.2.9"],"allowedNfTypes":["SCP","PCF","AF"],"priority":0,"capacity":100,"load":0,"nfServices":[{"serviceInstanceId":"70160cec-d738-41f1-8000-7d41e35e6ddd","serviceName":"nbsf-management","versions":[{"apiVersionInUri":"v1","apiFullVersion":"1.0.0"}],"scheme":"http","nfServiceStatus":"REGISTERED","ipEndPoints":[{"ipv4Address":"10.100.2.9","port":7777}],"allowedNfTypes":["PCF","AF"],"priority":0,"capacity":100,"load":0}],"nfProfileChangesSupportInd":true},{"nfInstanceId":"70d08e96-d738-41f1-99ed-89cb72d21d82","nfType":"BSF","nfStatus":"REGISTERED","heartBeatTimer":10,"plmnList":[{"mcc":"999","mnc":"70"}],"ipv4Addresses":["10.100.0.34"],"allowedNfTypes":["SCP","PCF","AF"],"priority":0,"capacity":100,"load":0,"nfServices":[{"serviceInstanceId":"70d09b16-d738-41f1-99ed-89cb72d21d82","serviceName":"nbsf-management","versions":[{"apiVersionInUri":"v1","apiFullVersion":"1.0.0"}],"scheme":"http","nfServiceStatus":"REGISTERED","ipEndPoints":[{"ipv4Address":"10.100.0.34","port":7777}],"allowedNfTypes":["PCF","AF"],"priority":0,"capacity":100,"load":0}],"nfProfileChangesSupportInd":true}]}
  ```

### 3.9 Deployment `09/15`: `open5gs-sepp` (Security Edge Protection Proxy — 3GPP TS 29.573 `N32c`/`N32f`)

- **Command**:
  ```bash
  kubectl -n open5gs get deploy/open5gs-sepp -o wide && \
  kubectl -n open5gs exec open5gs-amf-0 -- curl -sS --http2-prior-knowledge \
    'http://open5gs-nrf.open5gs.svc.cluster.local:7777/nnrf-disc/v1/nf-instances?target-nf-type=SEPP&requester-nf-type=AMF'
  ```
- **Response Printout**:
  ```text
  NAME           READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                             SELECTOR
  open5gs-sepp   2/2     2            2           87m   seppd        docker.io/gradiant/open5gs:2.7.2   nf=sepp
  {"validityPeriod":30,"nfInstances":[{"nfInstanceId":"73c6171a-d738-41f1-8184-d916d324b9b8","nfType":"SEPP","nfStatus":"REGISTERED","heartBeatTimer":10,"plmnList":[{"mcc":"999","mnc":"70"}],"ipv4Addresses":["10.100.1.35"],"priority":0,"capacity":100,"load":0,"nfProfileChangesSupportInd":true,"seppInfo":{"seppPorts":{"http":7777}}},{"nfInstanceId":"71d78772-d738-41f1-ba2d-ddaa4f328582","nfType":"SEPP","nfStatus":"REGISTERED","heartBeatTimer":10,"plmnList":[{"mcc":"999","mnc":"70"}],"ipv4Addresses":["10.100.2.15"],"priority":0,"capacity":100,"load":0,"nfProfileChangesSupportInd":true,"seppInfo":{"seppPorts":{"http":7777}}}]}
  ```

### 3.10 Deployment `10/15`: `open5gs-hss` (4G EPC Home Subscriber Server — `Diameter S6a`)

- **Command**:
  ```bash
  kubectl -n open5gs get deploy/open5gs-hss -o wide && \
  kubectl -n open5gs logs deploy/open5gs-hss --tail=6
  ```
- **Response Printout**:
  ```text
  NAME          READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                             SELECTOR
  open5gs-hss   1/1     1            1           87m   hssd         docker.io/gradiant/open5gs:2.7.2   nf=hss
  Open5GS daemon v2.7.2

  11/03 03:57:59.480: [app] INFO: Configuration: '/tmp/hss.yaml' (../lib/app/ogs-init.c:133)
  11/03 03:57:59.544: [dbi] INFO: MongoDB URI: 'mongodb://*****:*****@open5gs-firestore-proxy.open5gs.svc.cluster.local:27017/open5gs-db?authSource=admin&authMechanism=SCRAM-SHA-256&retryWrites=false' (../lib/dbi/ogs-mongoc.c:130)
  11/03 03:57:59.575: [app] INFO: HSS initialize...done (../src/hss/app-init.c:31)
  11/03 03:57:59.581: [diam] INFO: CONNECTED TO 'mme.gradiant' (TCP,soc#14): (../lib/diameter/common/logger.c:108)
  ```

### 3.11 Deployment `11/15`: `open5gs-pcrf` (4G EPC Policy & Charging Rules Function — `Diameter Gx`)

- **Command**:
  ```bash
  kubectl -n open5gs get deploy/open5gs-pcrf -o wide && \
  kubectl -n open5gs logs deploy/open5gs-pcrf --tail=6
  ```
- **Response Printout**:
  ```text
  NAME           READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                             SELECTOR
  open5gs-pcrf   1/1     1            1           87m   pcrfd        docker.io/gradiant/open5gs:2.7.2   nf=pcrf

  11/03 04:23:46.761: [app] INFO: Configuration: '/tmp/pcrf.yaml' (../lib/app/ogs-init.c:133)
  11/03 04:23:46.762: [pcrf] WARNING: unknown key `metrics` (../src/pcrf/pcrf-context.c:346)
  11/03 04:23:46.867: [dbi] INFO: MongoDB URI: 'mongodb://*****:*****@open5gs-firestore-proxy.open5gs.svc.cluster.local:27017/open5gs-db?authSource=admin&authMechanism=SCRAM-SHA-256&retryWrites=false' (../lib/dbi/ogs-mongoc.c:130)
  11/03 04:23:46.905: [app] INFO: PCRF initialize...done (../src/pcrf/app-init.c:31)
  11/03 04:23:46.911: [diam] INFO: CONNECTED TO 'smf.gradiant' (TCP,soc#14): (../lib/diameter/common/logger.c:108)
  ```

### 3.12 Deployment `12/15`: `open5gs-firestore-proxy` (MongoDB Wire-Protocol -> Cloud Firestore TLS Adapter)

- **Command**:
  ```bash
  kubectl -n open5gs get deploy/open5gs-firestore-proxy -o wide && \
  kubectl -n open5gs logs deploy/open5gs-firestore-proxy --tail=4
  ```
- **Response Printout**:
  ```text
  NAME                      READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                                   SELECTOR
  open5gs-firestore-proxy   2/2     2            2           64m   proxy        docker.io/gradiant/open5gs-webui:2.7.2   app=open5gs-firestore-proxy
  Found 2 pods, using pod/open5gs-firestore-proxy-56d4b6dc4c-8ljxz
  Cloud Firestore MongoDB Wire-Protocol Adapter listening on :27017 -> 057b3fe8-edc1-4d68-8c49-c21879886773.us-central1.firestore.goog:443 (TLS + loadBalanced=true)
  ```

### 3.13 Deployment `13/15`: `open5gs-webui` (Subscriber NMS WebUI + GCE External ALB + Cloud Armor)

- **Command**:
  ```bash
  kubectl -n open5gs get deploy/open5gs-webui svc/open5gs-webui-svc -o wide && \
  kubectl -n open5gs exec deploy/open5gs-scp -- \
    curl -sS -I http://open5gs-webui-svc.open5gs.svc.cluster.local:9999/ | head -n 8
  ```
- **Response Printout**:
  ```text
  NAME                            READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS   IMAGES                                   SELECTOR
  deployment.apps/open5gs-webui   1/1     1            1           163m   webui        docker.io/gradiant/open5gs-webui:2.7.2   app=open5gs-webui

  NAME                        TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE    SELECTOR
  service/open5gs-webui-svc   ClusterIP   10.200.14.13   <none>        9999/TCP   163m   app=open5gs-webui
  HTTP/1.1 200 OK
  X-Powered-By: Next.js 3.2.3
  ETag: "2273-9LHheKVZBe7gRWZ3nWQVEYfN0SE"
  Content-Type: text/html
  Content-Length: 8819
  Set-Cookie: connect.sid=s%3AApqOiKwyGCZKibcmTrmhwAkbYEkMx9Z0.cowDolyAdzA9f8nRfQwGmHNCYXhWTQGEDBHGhuJJC4M; Path=/; Expires=Tue, 17 Nov 2026 06:15:49 GMT; HttpOnly
  Date: Tue, 03 Nov 2026 06:15:49 GMT
  Connection: keep-alive
  ```

### 3.14 Deployment `14/15`: `ueransim-gnb` (Multi-NIC 5G gNodeB Simulator — `vpc-n2` SCTP & `vpc-n3` GTP-U)

- **Command**:
  ```bash
  kubectl -n open5gs get deploy/ueransim-gnb -o wide && \
  kubectl -n open5gs exec deploy/ueransim-gnb -- sh -c \
    'ip -4 -br addr | grep -E "^(eth0|net)"; nr-cli $(nr-cli -d | head -n1) -e status; nr-cli $(nr-cli -d | head -n1) -e amf-list'
  ```
- **Response Printout**:
  ```text
  NAME           READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                              SELECTOR
  ueransim-gnb   1/1     1            1           57m   nr-gnb       docker.io/gradiant/ueransim:3.2.6   app=ueransim-gnb
  net1@if47        UP             10.120.0.4/32 
  net2@if49        UP             10.130.0.3/32 
  eth0@if51        UP             10.100.3.12/32 
  is-ngap-up: true
  - id: 2
  ```

### 3.15 Deployment `15/15`: `ueransim-ue` (5G SA UE Simulator — `IMSI 999700000000001` + `uesimtun0` N6 Breakout)

- **Command**:
  ```bash
  kubectl -n open5gs get deploy/ueransim-ue -o wide && \
  kubectl -n open5gs exec deploy/ueransim-ue -- sh -c \
    'nr-cli imsi-999700000000001 -e status; nr-cli imsi-999700000000001 -e ps-list; ping -I uesimtun0 -c 3 8.8.8.8; curl -sS --interface uesimtun0 -I https://www.google.com | head -n 5'
  ```
- **Response Printout**:
  ```text
  NAME          READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                              SELECTOR
  ueransim-ue   1/1     1            1           57m   nr-ue        docker.io/gradiant/ueransim:3.2.6   app=ueransim-ue
  cm-state: CM-CONNECTED
  rm-state: RM-REGISTERED
  mm-state: MM-REGISTERED/NORMAL-SERVICE
  5u-state: 5U1-UPDATED
  sim-inserted: true
  selected-plmn: 999/70
  current-cell: 1
  current-plmn: 999/70
  current-tac: 1
  last-tai: PLMN[999/70] TAC[1]
  stored-suci: no-identity
  stored-guti: 
   plmn: 999/70
   amf-region-id: 0x02
   amf-set-id: 1
   amf-pointer: 0
   tmsi: 0xc0000319
  has-emergency: false
  PDU Session1: 
   state: PS-ACTIVE
   session-type: IPv4
   apn: internet
   s-nssai: 
    sst: 0x01
    sd: 0x010203
   emergency: false
   address: 10.45.0.3
   ambr: up[1000000Kb/s] down[1000000Kb/s]
   data-pending: false
  PING 8.8.8.8 (8.8.8.8) from 10.45.0.3 uesimtun0: 56(84) bytes of data.
  64 bytes from 8.8.8.8: icmp_seq=1 ttl=113 time=9.51 ms
  64 bytes from 8.8.8.8: icmp_seq=2 ttl=113 time=2.74 ms
  64 bytes from 8.8.8.8: icmp_seq=3 ttl=113 time=2.80 ms

  --- 8.8.8.8 ping statistics ---
  3 packets transmitted, 3 received, 0% packet loss, time 2003ms
  rtt min/avg/max/mdev = 2.735/5.015/9.514/3.180 ms
  HTTP/2 200 
  content-type: text/html; charset=ISO-8859-1
  content-security-policy-report-only: object-src 'none';base-uri 'self';script-src 'nonce--HInTbbMot051bjFwRToTA' 'strict-dynamic' 'report-sample' 'unsafe-eval' 'unsafe-inline' https: http:;report-uri https://csp.withgoogle.com/csp/gws/other-hp
  accept-ch: Sec-CH-Prefers-Color-Scheme
  p3p: CP="This is not a P3P policy! See g.co/p3phelp for more info."
  ```

---

### 3.16 StatefulSet `01/06`: `open5gs-amf` (Multi-NIC Access & Mobility Management Function — `N1`/`N2` + `:9090`)

- **Command**:
  ```bash
  kubectl -n open5gs get sts/open5gs-amf pod/open5gs-amf-0 -o wide && \
  kubectl -n open5gs exec open5gs-amf-0 -- sh -c \
    'ip -4 -br addr | grep -E "^(eth0|net)"; curl -sS http://$(hostname -i):9090/metrics | grep -E "^(gnb|ran_ue|amf_session|fivegs_amffunction_rm_reginitsucc) "'
  ```
- **Response Printout**:
  ```text
  NAME                           READY   AGE   CONTAINERS   IMAGES
  statefulset.apps/open5gs-amf   1/1     87m   amfd         docker.io/gradiant/open5gs:2.7.2

  NAME                READY   STATUS    RESTARTS   AGE   IP           NODE                                                  NOMINATED NODE   READINESS GATES
  pod/open5gs-amf-0   1/1     Running   0          64m   10.100.3.5   gke-open5gs-5gc-clus-upf-amf-multinic-5b2d8431-9m43   <none>           <none>
  net1@if19        UP             10.120.0.2/32 
  eth0@if21        UP             10.100.3.5/32 
  gnb 1
  fivegs_amffunction_rm_reginitsucc 2
  amf_session 1
  ran_ue 1
  ```

### 3.17 StatefulSet `02/06`: `open5gs-smf` (Multi-NIC Session Management Function / PGW-C — `N4` PFCP + `:9090`)

- **Command**:
  ```bash
  kubectl -n open5gs get sts/open5gs-smf pod/open5gs-smf-0 -o wide && \
  kubectl -n open5gs exec open5gs-smf-0 -- sh -c \
    'ip -4 -br addr | grep -E "^(eth0|net)"; curl -sS http://$(hostname -i):9090/metrics | grep -E "^(ues_active|fivegs_smffunction_sm_sessionnbr|fivegs_smffunction_sm_qos_flow_nbr)"'
  ```
- **Response Printout**:
  ```text
  NAME                           READY   AGE   CONTAINERS   IMAGES
  statefulset.apps/open5gs-smf   1/1     88m   smfd         docker.io/gradiant/open5gs:2.7.2

  NAME                READY   STATUS    RESTARTS   AGE   IP            NODE                                                  NOMINATED NODE   READINESS GATES
  pod/open5gs-smf-0   1/1     Running   0          58m   10.100.3.10   gke-open5gs-5gc-clus-upf-amf-multinic-5b2d8431-9m43   <none>           <none>
  net1@if39        UP             10.140.0.5/32 
  eth0@if41        UP             10.100.3.10/32 
  ues_active 1
  fivegs_smffunction_sm_sessionnbr{plmnid="99970",snssai="1-010203"} 1
  fivegs_smffunction_sm_qos_flow_nbr{plmnid="99970",snssai="1-010203",fiveqi="9"} 2
  ```

### 3.18 StatefulSet `03/06`: `open5gs-upf` (Dedicated Multi-NIC User Plane Function — `N3`/`N4`/`N6` + `ogstun` + `:9090`)

- **Command**:
  ```bash
  kubectl -n open5gs get sts/open5gs-upf pod/open5gs-upf-0 -o wide && \
  kubectl -n open5gs exec open5gs-upf-0 -c upfd -- sh -c \
    'ip -4 -br addr | grep -E "^(eth0|net|ogstun)"; ip rule show | grep 200; ip -s link show ogstun; curl -sS http://$(hostname -i):9090/metrics | grep -E "^(fivegs_upffunction_upf_sessionnbr|fivegs_upffunction_upf_qosflows|fivegs_upffunction_sm_n4sessionestabreq)"'
  ```
- **Response Printout**:
  ```text
  NAME                           READY   AGE   CONTAINERS   IMAGES
  statefulset.apps/open5gs-upf   1/1     88m   upfd         docker.io/gradiant/open5gs:2.7.2

  NAME                READY   STATUS    RESTARTS   AGE   IP           NODE                                                  NOMINATED NODE   READINESS GATES
  pod/open5gs-upf-0   1/1     Running   0          60m   10.100.4.6   gke-open5gs-5gc-clus-upf-amf-multinic-197ba8e5-6qnf   <none>           <none>
  ogstun           UP             10.45.0.1/16 
  net1@if25        UP             10.130.0.35/32 
  net2@if27        UP             10.140.0.35/32 
  net3@if29        UP             10.160.0.35/32 
  eth0@if31        UP             10.100.4.6/32 
  32765:	from 10.45.0.0/16 lookup 200
  2: ogstun: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1400 qdisc fq state UP mode DEFAULT group default qlen 500
      link/none 
      RX: bytes  packets  errors  dropped missed  mcast   
      13035      146      0       0       0       0       
      TX: bytes  packets  errors  dropped carrier collsns 
      124374     169      0       0       0       0       
  fivegs_upffunction_sm_n4sessionestabreq 2
  fivegs_upffunction_upf_sessionnbr 1
  fivegs_upffunction_upf_qosflows{dnn="internet"} 1
  ```

### 3.19 StatefulSet `04/06`: `open5gs-mme` (Multi-NIC 4G Mobility Management Entity — `S1-MME` / `S11` / `S6a` + `:9090`)

- **Command**:
  ```bash
  kubectl -n open5gs get sts/open5gs-mme pod/open5gs-mme-0 -o wide && \
  kubectl -n open5gs exec open5gs-mme-0 -- sh -c \
    'ip -4 -br addr | grep -E "^(eth0|net)"; curl -sS http://$(hostname -i):9090/metrics | grep -E "^(enb|mme_session) "' && \
  kubectl -n open5gs logs open5gs-mme-0 --tail=4
  ```
- **Response Printout**:
  ```text
  NAME                           READY   AGE   CONTAINERS   IMAGES
  statefulset.apps/open5gs-mme   1/1     87m   mmed         docker.io/gradiant/open5gs:2.7.2

  NAME                READY   STATUS    RESTARTS      AGE   IP           NODE                                                  NOMINATED NODE   READINESS GATES
  pod/open5gs-mme-0   1/1     Running   2 (62m ago)   62m   10.100.3.7   gke-open5gs-5gc-clus-upf-amf-multinic-5b2d8431-9m43   <none>           <none>
  net1@if25        UP             10.120.0.3/32 
  eth0@if27        UP             10.100.3.7/32 
  mme_session 0
  enb 0
  11/03 03:57:36.888: [gtp] INFO: gtp_connect() [10.100.3.8]:2123 (../lib/gtp/path.c:60)
  11/03 03:57:36.888: [mme] INFO: s1ap_server() [10.120.0.3]:36412 (../src/mme/s1ap-sctp.c:62)
  11/03 03:57:36.888: [sctp] INFO: MME initialize...done (../src/mme/app-init.c:33)
  11/03 03:57:59.580: [diam] INFO: CONNECTED TO 'hss.gradiant' (TCP,soc#7): (../lib/diameter/common/logger.c:108)
  ```

### 3.20 StatefulSet `05/06`: `open5gs-sgwc` (Multi-NIC 4G SGW Control Plane — `S11` GTP-C & `Sxa` PFCP)

- **Command**:
  ```bash
  kubectl -n open5gs get sts/open5gs-sgwc pod/open5gs-sgwc-0 -o wide && \
  kubectl -n open5gs exec open5gs-sgwc-0 -- sh -c 'ip -4 -br addr | grep -E "^(eth0|net)"' && \
  kubectl -n open5gs logs open5gs-sgwc-0 --tail=4
  ```
- **Response Printout**:
  ```text
  NAME                            READY   AGE   CONTAINERS   IMAGES
  statefulset.apps/open5gs-sgwc   1/1     88m   sgwcd        docker.io/gradiant/open5gs:2.7.2

  NAME                 READY   STATUS    RESTARTS   AGE   IP            NODE                                                  NOMINATED NODE   READINESS GATES
  pod/open5gs-sgwc-0   1/1     Running   0          58m   10.100.3.11   gke-open5gs-5gc-clus-upf-amf-multinic-5b2d8431-9m43   <none>           <none>
  net1@if43        UP             10.140.0.6/32 
  eth0@if45        UP             10.100.3.11/32 
  11/03 04:01:38.851: [pfcp] INFO: pfcp_server() [10.140.0.6]:8805 (../lib/pfcp/path.c:30)
  11/03 04:01:38.851: [pfcp] INFO: ogs_pfcp_connect() [10.140.0.4]:8805 (../lib/pfcp/path.c:61)
  11/03 04:01:38.851: [app] INFO: SGW-C initialize...done (../src/sgwc/app.c:31)
  11/03 04:01:38.852: [sgwc] INFO: PFCP associated [10.140.0.4]:8805 (../src/sgwc/pfcp-sm.c:183)
  ```

### 3.21 StatefulSet `06/06`: `open5gs-sgwu` (Multi-NIC 4G SGW User Plane — `S1-U` GTP-U & `Sxa` PFCP)

- **Command**:
  ```bash
  kubectl -n open5gs get sts/open5gs-sgwu pod/open5gs-sgwu-0 -o wide && \
  kubectl -n open5gs exec open5gs-sgwu-0 -- sh -c 'ip -4 -br addr | grep -E "^(eth0|net)"' && \
  kubectl -n open5gs logs open5gs-sgwu-0 --tail=4
  ```
- **Response Printout**:
  ```text
  NAME                            READY   AGE   CONTAINERS   IMAGES
  statefulset.apps/open5gs-sgwu   1/1     88m   sgwud        docker.io/gradiant/open5gs:2.7.2

  NAME                 READY   STATUS    RESTARTS   AGE   IP           NODE                                                  NOMINATED NODE   READINESS GATES
  pod/open5gs-sgwu-0   1/1     Running   0          62m   10.100.3.9   gke-open5gs-5gc-clus-upf-amf-multinic-5b2d8431-9m43   <none>           <none>
  net1@if33        UP             10.130.0.2/32 
  net2@if35        UP             10.140.0.4/32 
  eth0@if37        UP             10.100.3.9/32 
  11/03 03:57:24.930: [gtp] INFO: gtp_server() [10.130.0.2]:2152 (../lib/gtp/path.c:30)
  11/03 03:57:24.930: [app] INFO: SGW-U initialize...done (../src/sgwu/app.c:31)
  11/03 04:01:38.851: [pfcp] INFO: ogs_pfcp_connect() [10.140.0.6]:8805 (../lib/pfcp/path.c:61)
  11/03 04:01:38.852: [sgwu] INFO: PFCP associated [10.140.0.6]:8805 (../src/sgwu/pfcp-sm.c:179)
  ```

---

### 3.22 End-to-End 5G User-Plane Speedtest (Simulated UE)

To validate sustained user-plane throughput, latency, jitter, and GTP-U packet encapsulation under load, a live external internet speedtest was executed from `deploy/ueransim-ue` bound strictly to the 5G PDU Session interface (`--interface uesimtun0`, `10.45.0.3`, `MTU 1400`) against Cloudflare's HTTPS benchmark endpoints (`speed.cloudflare.com`, `colo=ORD`, TLS 1.3).

- **Verified End-to-End 5G Data Path**:
  `ueransim-ue (uesimtun0: 10.45.0.3)` → `NR-Uu` → `ueransim-gnb` → `N3 GTP-U (:2152, vpc-n3-userplane, MTU 8896)` → `open5gs-upf-0 (ogstun on c3-standard-8 + gVNIC)` → `N6 (net3, vpc-n6-dn)` → `Cloud NAT (open5gs-n6-nat)` → `Public Internet`

#### Speedtest Results Summary

| Metric | Test Configuration (`--interface uesimtun0`) | Measured Result | Status |
| :--- | :--- | :--- | :---: |
| **Ping Latency (Avg / Min / Max)** | `10` ICMP packets to `8.8.8.8` (`0.2s` interval) | **`1.93 ms`** (`1.79 ms` / `2.62 ms`) | **PASS** |
| **Jitter (`mdev`) & Packet Loss** | `10` ICMP packets over `uesimtun0` | **`0.23 ms`** jitter • **`0%`** packet loss | **PASS** |
| **Download Speed (Single-Stream)** | `50 MB` HTTPS (`speed.cloudflare.com/__down`) | **`401.74 Mbps`** (`0.996 s`, TTFB `197 ms`) | **PASS** |
| **Download Speed (4 Parallel Streams)** | `4 × 50 MB` (`200 MB` total HTTPS) | **`623.87 Mbps`** (`2.565 s`) | **PASS** |
| **Upload Speed (Single-Stream)** | `50 MiB` HTTPS POST (`speed.cloudflare.com/__up`) | **`260.58 Mbps`** (`1.610 s`) | **PASS** |
| **Upload Speed (4 Parallel Streams)** | `4 × 25 MiB` (`100 MiB` total HTTPS POST) | **`329.09 Mbps`** (`2.549 s`) | **PASS** |
| **UPF `ogstun` GTP-U Payload Verified** | Kernel `RX` + `TX` delta on `open5gs-upf-0` | **`460.31 MB`** (`386,380` pkts, `0` errors) | **PASS** |

- **Commands**:
  ```bash
  # 1. Baseline UPF ogstun packet/byte counters before speedtest
  kubectl -n open5gs exec open5gs-upf-0 -c upfd -- ip -s link show ogstun

  # 2. ICMP Latency & Jitter over uesimtun0
  kubectl -n open5gs exec deploy/ueransim-ue -- ping -I uesimtun0 -c 10 -i 0.2 8.8.8.8

  # 3. Single-Stream (50 MB) & Multi-Stream (4x 50 MB = 200 MB) HTTPS Download via uesimtun0
  kubectl -n open5gs exec deploy/ueransim-ue -- curl -s --interface uesimtun0 -o /dev/null \
    -w "HTTP: %{http_code} | Downloaded: %{size_download} bytes | Time: %{time_total}s | TTFB: %{time_starttransfer}s | Speed: %{speed_download} B/s\n" \
    "https://speed.cloudflare.com/__down?bytes=50000000"

  kubectl -n open5gs exec deploy/ueransim-ue -- sh -c '
    start=$(date +%s%N)
    for i in 1 2 3 4; do
      curl -s --interface uesimtun0 -o /dev/null "https://speed.cloudflare.com/__down?bytes=50000000" &
    done
    wait
    end=$(date +%s%N)
    awk -v s="$start" -v e="$end" "BEGIN { dt=(e-s)/1e9; mbps=(200000000*8)/(dt*1e6); printf \"Total: 200 MB | Elapsed: %.3fs | Aggregate Download: %.2f Mbps\n\", dt, mbps }"
  '

  # 4. Single-Stream (50 MiB) & Multi-Stream (4x 25 MiB = 100 MiB) HTTPS Upload via uesimtun0
  kubectl -n open5gs exec deploy/ueransim-ue -- sh -c '
    dd if=/dev/zero bs=1M count=50 2>/dev/null | curl -s --interface uesimtun0 -X POST --data-binary @- -o /dev/null \
      -w "Uploaded: %{size_upload} bytes | Time: %{time_total}s | Speed: %{speed_upload} B/s\n" "https://speed.cloudflare.com/__up"
  '

  kubectl -n open5gs exec deploy/ueransim-ue -- sh -c '
    dd if=/dev/zero of=/tmp/up25m.bin bs=1M count=25 2>/dev/null
    start=$(date +%s%N)
    for i in 1 2 3 4; do
      curl -s --interface uesimtun0 -X POST --data-binary @/tmp/up25m.bin -o /dev/null "https://speed.cloudflare.com/__up" &
    done
    wait
    end=$(date +%s%N)
    rm -f /tmp/up25m.bin
    awk -v s="$start" -v e="$end" "BEGIN { dt=(e-s)/1e9; mbps=(104857600*8)/(dt*1e6); printf \"Total: 100 MiB | Elapsed: %.3fs | Aggregate Upload: %.2f Mbps\n\", dt, mbps }"
  '

  # 5. Post-test UPF ogstun packet/byte counters confirming full N3 GTP-U traversal
  kubectl -n open5gs exec open5gs-upf-0 -c upfd -- ip -s link show ogstun
  ```
- **Response Printout**:
  ```text
  # UPF ogstun (Before Speedtest)
  2: ogstun: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1400 qdisc fq state UP mode DEFAULT group default qlen 500
      link/none
      RX: bytes  packets  errors  dropped missed  mcast
      15119      167      0       0       0       0
      TX: bytes  packets  errors  dropped carrier collsns
      130514     185      0       0       0       0

  # ICMP Ping Latency & Jitter (10 packets, 0.2s interval)
  PING 8.8.8.8 (8.8.8.8) from 10.45.0.3 uesimtun0: 56(84) bytes of data.
  10 packets transmitted, 10 received, 0% packet loss, time 1810ms
  rtt min/avg/max/mdev = 1.786/1.933/2.620/0.232 ms

  # HTTPS Download & Upload Speedtests (Cloudflare colo=ORD, TLSv1.3)
  HTTP: 200 | Downloaded: 50000000 bytes | Time: 0.995678s | TTFB: 0.196694s | Speed: 50217038 B/s  (401.74 Mbps)
  Total: 200 MB  | Elapsed: 2.565s | Aggregate Download: 623.87 Mbps
  Uploaded: 52428800 bytes | Time: 1.609587s | Speed: 32572827 B/s                                  (260.58 Mbps)
  Total: 100 MiB | Elapsed: 2.549s | Aggregate Upload: 329.09 Mbps

  # UPF ogstun (After Speedtest)
  2: ogstun: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1400 qdisc fq state UP mode DEFAULT group default qlen 500
      link/none
      RX: bytes  packets  errors  dropped missed  mcast
      166206313  160003   0       0       0       0
      TX: bytes  packets  errors  dropped carrier collsns
      294254225  226729   0       168     0       0
  ```
- **Performance Observation**: Sustaining **`623.87 Mbps` downlink** and **`329.09 Mbps` uplink** at **`1.93 ms` RTT** confirms high-efficiency packet forwarding across the `c3-standard-8` (`gVNIC`) UPF node pool and `MTU 8896` `N3` VPC fabric, even with two userspace Linux `TUN` context switches (`uesimtun0` in `nr-ue` and `ogstun` in `open5gs-upfd`) plus userspace `NR-Uu` PDCP/RLC/GTP-U framing within the subscriber's `1 Gbps` UE-AMBR QoS profile.

---

## 4. Step-by-Step Test Execution Procedures (SOP)

This section provides repeatable procedures for testers to reproduce **Item 2** (provisioning a UE subscriber profile via the Open5GS NMS WebUI and attaching the UE) and **Item 3** (executing functional verification across every Deployment and StatefulSet).

### 4.0 Prerequisites — Authenticate to GCP & GKE Cluster

```bash
# 1. Authenticate gcloud CLI and configure project context
gcloud config set project open5gs-513602

# 2. Fetch kubeconfig credentials for the regional GKE cluster
gcloud container clusters get-credentials open5gs-5gc-cluster \
  --region us-central1 \
  --project open5gs-513602

# 3. Retrieve the NMS WebUI Ingress endpoint (or port-forward svc/open5gs-webui-svc:9999)
kubectl -n open5gs get ingress open5gs-nms-ingress
```

---

### 4.1 Procedure for Item 2: Registering the UE Subscriber Profile in NMS WebUI & Attaching the UE

#### Step 1: Log in to the Open5GS NMS WebUI
1. Open a browser and navigate to the External Application Load Balancer endpoint reported by `kubectl -n open5gs get ingress open5gs-nms-ingress` (or access locally via `kubectl -n open5gs port-forward svc/open5gs-webui-svc 9999:9999` -> `localhost:9999`; when IAP + HTTPS domain are enabled in production, authenticate via Google Identity-Aware Proxy SSO first).
2. On the Open5GS login screen, sign in with the NMS administrator account:
   - **Username**: `admin`
   - **Password**: *(Initial upstream Open5GS WebUI seed password `1423`; rotate immediately under **Navigation -> Accounts** for non-lab environments)*.
3. Confirm the left navigation drawer opens to **Subscribers**.

#### Step 2: Create or Edit the UE Subscriber Profile (`IMSI 999700000000001`)
1. On the **Subscribers** page, click the floating **`+` (Add Subscriber)** button in the bottom-right corner (or click an existing subscriber card and click the **Edit (pencil)** icon).
2. Populate the **Subscriber Configuration** form with the exact 3GPP USIM and slice parameters matching the UE simulator (`k8s/04-ueransim-ran-ue-simulator.yaml`):
   - **IMSI**: `999700000000001` *(PLMN `999`/`70`, MSIN `0000000001`)*
   - **Subscriber Key (`K`)**: `465B5CE8B199B49FAA5F0A2EE238A6BC`
   - **USIM Type**: Select **`OPc`** and enter `E8ED289DEBA952E4283B54E88E6183CA`
   - **AMF**: `8000`
   - **Operator Provided (`IMEISV`)**: `4370816125816151` *(or leave auto-populated from UE attach)*
   - **Subscribed UE-AMBR**:
     - **Downlink**: `1` `Gbps` (`1000000000 bps`)
     - **Uplink**: `1` `Gbps` (`1000000000 bps`)
3. Under **Slice Configurations**, configure the default eMBB slice:
   - **SST**: `1`
   - **SD**: `010203`
   - **Default S-NSSAI**: Checked (`true`)
4. Under **Session Configurations** inside Slice `SST:1 / SD:010203`, configure the data network:
   - **DNN / APN**: `internet`
   - **Type**: `IPv4v6`
   - **5QI / QCI**: `9`
   - **ARP Priority Level**: `8` (`Pre-emption Capability: Disabled`, `Pre-emption Vulnerability: Disabled`)
   - **Session-AMBR Downlink / Uplink**: `1` `Gbps` / `1` `Gbps`
5. Click **Save** at the bottom of the modal. The NMS WebUI persists the subscriber document through `open5gs-firestore-proxy:27017` directly into **Cloud Firestore Enterprise (`open5gs-db.subscribers`)**.

#### Step 3: Verify Database Persistence via UDR (`nudr-dr`)
Confirm that Open5GS `UDR` immediately reads the provisioned subscriber record from Cloud Firestore:

```bash
kubectl -n open5gs exec deploy/open5gs-udm -- curl -sS --http2-prior-knowledge \
  'http://open5gs-udr.open5gs.svc.cluster.local:7777/nudr-dr/v1/subscription-data/imsi-999700000000001/authentication-data/authentication-subscription'
```
- **Expected Output**: JSON containing `"authenticationMethod":"5G_AKA"`, `"encPermanentKey":"465b5ce8b199b49faa5f0a2ee238a6bc"`, and `"encOpcKey":"e8ed289deba952e4283b54e88e6183ca"`.

#### Step 4: Trigger UE Registration & PDU Session Establishment
1. Verify that `k8s/04-ueransim-ran-ue-simulator.yaml` (`ConfigMap/ueransim-config`, key `ue.yaml`) has matching `supi: 'imsi-999700000000001'`, `key`, `op`, `OPc`, `mcc: '999'`, `mnc: '70'`, `apn: 'internet'`, `sst: 1`, and `sd: 0x010203`.
2. Restart (or deploy) `ueransim-ue` to initiate a fresh 5G-AKA Registration and PDU Session Establishment:
   ```bash
   kubectl -n open5gs rollout restart deploy/ueransim-ue
   kubectl -n open5gs rollout status deploy/ueransim-ue --timeout=60s
   ```
3. Verify UE attachment and allocated `uesimtun0` IPv4 address (`10.45.0.x`):
   ```bash
   kubectl -n open5gs exec deploy/ueransim-ue -- nr-cli imsi-999700000000001 -e status
   kubectl -n open5gs exec deploy/ueransim-ue -- nr-cli imsi-999700000000001 -e ps-list
   ```
   - **Pass Criteria**: `cm-state: CM-CONNECTED`, `rm-state: RM-REGISTERED`, `state: PS-ACTIVE`, and `address: 10.45.0.x`.

---

### 4.2 Procedure for Item 3: Executing Functional Tests Across All Deployments & StatefulSets

Execute the verification checks in the 6 logical stages below so upstream control-plane dependencies are validated before downstream signaling and user-plane traffic.

#### Stage 1: Verify All 21 Workload Rollout States (`15` Deployments + `6` StatefulSets)
```bash
kubectl -n open5gs get deploy,sts -o wide
```
- **Pass Criteria**: Every `Deployment` (`15/15`) and `StatefulSet` (`6/6`) reports `READY` replicas equal to desired replicas (`1/1` or `2/2`) with zero crash-looping pods.

#### Stage 2: Test 5G SBA Control Plane Deployments (`NRF`, `SCP`, `UDR`, `UDM`, `AUSF`, `PCF`, `NSSF`, `BSF`, `SEPP`)
Run HTTP/2 Prior-Knowledge (`--http2-prior-knowledge`) SBI requests inside the cluster network (`vpc-sbi` `:7777`) and query `:9090/metrics`:
1. **`open5gs-nrf`**: Query `/nnrf-nfm/v1/nf-instances` from `deploy/open5gs-scp` (Command in [Section 3.1](#31-deployment-0115-open5gs-nrf-nf-repository-function--3gpp-ts-29510)) — verify `_links.items` lists all registered 5G NFs.
2. **`open5gs-scp`**: Query `/nnrf-disc/v1/nf-instances?target-nf-type=SCP&requester-nf-type=AMF` (Command in [Section 3.2](#32-deployment-0215-open5gs-scp-service-communication-proxy--indirect-sba-mesh)) — verify `2` `REGISTERED` SCP instances.
3. **`open5gs-udr`**: Query `/nudr-dr/v1/subscription-data/imsi-999700000000001/authentication-data/authentication-subscription` from `deploy/open5gs-udm` (Command in [Section 3.3](#33-deployment-0315-open5gs-udr-unified-data-repository--3gpp-ts-29504-nudr-dr)) — verify `5G_AKA` keys return from Firestore.
4. **`open5gs-udm`**: Query `/nudm-sdm/v2/imsi-999700000000001/am-data` from `deploy/open5gs-ausf` (Command in [Section 3.4](#34-deployment-0415-open5gs-udm-unified-data-management--3gpp-ts-29503-nudm-sdm)) — verify `subscribedUeAmbr` (`1000000 Kbps`) and default S-NSSAI (`sst: 1, sd: "010203"`).
5. **`open5gs-ausf`**: Query `nnrf-disc` for `target-nf-type=AUSF` (Command in [Section 3.5](#35-deployment-0515-open5gs-ausf-authentication-server-function--3gpp-ts-29509-nausf-auth)) — verify `2` `REGISTERED` `nausf-auth` endpoints.
6. **`open5gs-pcf`**: Scrape `http://$(hostname -i):9090/metrics` inside `deploy/open5gs-pcf` (Command in [Section 3.6](#36-deployment-0615-open5gs-pcf-policy-control-function--3gpp-ts-29507--ts-29512--9090)) — verify `fivegs_pcffunction_pa_sessionnbr >= 1` and non-zero AM/SM policy association counters.
7. **`open5gs-nssf`**: Query `/nnssf-nsselection/v2/network-slice-information` with `slice-info-request-for-pdu-session` for `sst=1, sd=010203` (Command in [Section 3.7](#37-deployment-0715-open5gs-nssf-network-slice-selection-function--3gpp-ts-29531-nnssf-nsselection)) — verify `nsiInformation` returns `nrfId` and `nsiId: "1"`.
8. **`open5gs-bsf` & `open5gs-sepp`**: Query `nnrf-disc` for `target-nf-type=BSF` and `target-nf-type=SEPP` (Commands in [Sections 3.8](#38-deployment-0815-open5gs-bsf-binding-support-function--3gpp-ts-29521-nbsf-management) & [3.9](#39-deployment-0915-open5gs-sepp-security-edge-protection-proxy--3gpp-ts-29573-n32cn32f)) — verify `2` `REGISTERED` instances each.

#### Stage 3: Test Persistence Adapter & NMS WebUI Deployments (`open5gs-firestore-proxy`, `open5gs-webui`)
1. **`open5gs-firestore-proxy`**: Inspect pod readiness (`2/2`) and container logs (Command in [Section 3.12](#312-deployment-1215-open5gs-firestore-proxy-mongodb-wire-protocol---cloud-firestore-tls-adapter)) — confirm `:27017` wire adapter is connected over TLS to `*.us-central1.firestore.goog:443`.
2. **`open5gs-webui`**: Check `deploy/open5gs-webui` and `svc/open5gs-webui-svc`, and run `curl -sS -I http://open5gs-webui-svc.open5gs.svc.cluster.local:9999/` (Command in [Section 3.13](#313-deployment-1315-open5gs-webui-subscriber-nms-webui--gce-external-alb--cloud-armor)) — confirm `HTTP/1.1 200 OK` and `Set-Cookie: connect.sid=...`.

#### Stage 4: Test 4G EPC CUPS Control & User Plane Workloads (`HSS`, `PCRF`, `MME`, `SGW-C`, `SGW-U`)
1. **`open5gs-hss` & `open5gs-pcrf` (Deployments)**: Inspect logs (Commands in [Sections 3.10](#310-deployment-1015-open5gs-hss-4g-epc-home-subscriber-server--diameter-s6a) & [3.11](#311-deployment-1115-open5gs-pcrf-4g-epc-policy--charging-rules-function--diameter-gx)) — confirm Firestore DB initialization and `CONNECTED TO 'mme.gradiant'` (`Diameter S6a`) and `CONNECTED TO 'smf.gradiant'` (`Diameter Gx`).
2. **`open5gs-mme` (StatefulSet)**: Verify Multi-NIC `net1` (`10.120.0.3` on `vpc-n2`), `:9090/metrics` (`enb`, `mme_session`), `S11` GTP-C (`10.100.3.8:2123`), `S1AP` SCTP (`:36412`), and `CONNECTED TO 'hss.gradiant'` (Command in [Section 3.19](#319-statefulset-0406-open5gs-mme-multi-nic-4g-mobility-management-entity--s1-mme--s11--s6a--9090)).
3. **`open5gs-sgwc` & `open5gs-sgwu` (StatefulSets)**: Verify Multi-NIC interfaces (`net1` on `vpc-n4` for `SGW-C`; `net1` on `vpc-n3` + `net2` on `vpc-n4` for `SGW-U`) and confirm bidirectional `PFCP associated` logs on UDP `:8805` (Commands in [Sections 3.20](#320-statefulset-0506-open5gs-sgwc-multi-nic-4g-sgw-control-plane--s11-gtp-c--sxa-pfcp) & [3.21](#321-statefulset-0606-open5gs-sgwu-multi-nic-4g-sgw-user-plane--s1-u-gtp-u--sxa-pfcp)).

#### Stage 5: Test Multi-NIC 5G Core StatefulSets (`AMF`, `SMF`, `UPF`) & RAN/UE Data Plane (`ueransim-gnb`, `ueransim-ue`)
1. **`open5gs-amf` (StatefulSet)**: Verify `net1` (`10.120.0.2` on `vpc-n2`) and `:9090/metrics` showing `gnb 1`, `ran_ue 1`, and `amf_session 1` (Command in [Section 3.16](#316-statefulset-0106-open5gs-amf-multi-nic-access--mobility-management-function--n1n2--9090)).
2. **`open5gs-smf` (StatefulSet)**: Verify `net1` (`10.140.0.5` on `vpc-n4`) and `:9090/metrics` showing `ues_active 1`, `fivegs_smffunction_sm_sessionnbr 1`, and `fivegs_smffunction_sm_qos_flow_nbr 2` (Command in [Section 3.17](#317-statefulset-0206-open5gs-smf-multi-nic-session-management-function--pgw-c--n4-pfcp--9090)).
3. **`open5gs-upf` (StatefulSet)**: Verify `4` VPC NICs (`eth0` SBI, `net1` N3 `10.130.0.35`, `net2` N4 `10.140.0.35`, `net3` N6 `10.160.0.35`), TUN interface `ogstun` (`10.45.0.1/16`), policy routing rule `from 10.45.0.0/16 lookup 200`, non-zero `RX`/`TX` packets with `0` drops on `ogstun`, and `:9090/metrics` `fivegs_upffunction_upf_sessionnbr 1` (Command in [Section 3.18](#318-statefulset-0306-open5gs-upf-dedicated-multi-nic-user-plane-function--n3n4n6--ogstun--9090)).
4. **`ueransim-gnb` & `ueransim-ue` (Deployments)**: Verify `is-ngap-up: true` on `ueransim-gnb` and execute live end-to-end ICMP (`ping -I uesimtun0 -c 3 8.8.8.8`) and HTTPS (`curl -sS --interface uesimtun0 -I https://www.google.com`) data-plane breakout from `ueransim-ue` through GTP-U (`vpc-n3`) -> `UPF` (`ogstun`) -> `vpc-n6` Cloud NAT (Commands in [Sections 3.14](#314-deployment-1415-ueransim-gnb-multi-nic-5g-gnodeb-simulator--vpc-n2-sctp--vpc-n3-gtp-u) & [3.15](#315-deployment-1515-ueransim-ue-5g-sa-ue-simulator--imsi-999700000000001--uesimtun0-n6-breakout)).

#### Stage 6: Confirm Telemetry Ingestion on the Cloud Monitoring "Open5GS" Dashboard
1. In the Google Cloud Console, navigate to **Monitoring -> Dashboards -> Open5GS** and set the time range to **Last 1 hour**.
2. Confirm all 4 top-row scorecards (`Connected 5G gNodeBs (N2 SCTP) = 1`, `Active AMF UE Sessions = 1`, `Active SMF PDU Sessions (S-NSSAI) = 1`, `Active UPF User Plane Sessions (N4) = 1`), all `:9090` 3GPP counter charts, and all GKE Deployment/StatefulSet availability and resource charts populate with human-readable workload names and zero container restarts.

---

### 4.3 Procedure for Executing the End-to-End 5G UE Speedtest

Follow these steps to reproduce the simulated 5G UE throughput and latency benchmark documented in [Section 3.22](#322-end-to-end-5g-user-plane-speedtest-simulated-ue):

1. **Verify Active UE PDU Session Tunnel (`uesimtun0`)**:
   ```bash
   kubectl -n open5gs exec deploy/ueransim-ue -- ip -4 addr show dev uesimtun0
   ```
   - **Pass Criteria**: `uesimtun0` is `UP` with an assigned `10.45.0.x/32` IPv4 address (`mtu 1400`).
2. **Record Baseline UPF `ogstun` Counters**:
   ```bash
   kubectl -n open5gs exec open5gs-upf-0 -c upfd -- ip -s link show ogstun
   ```
3. **Run ICMP Latency & Jitter Check**:
   ```bash
   kubectl -n open5gs exec deploy/ueransim-ue -- ping -I uesimtun0 -c 10 -i 0.2 8.8.8.8
   ```
   - **Pass Criteria**: `0% packet loss` and sub-`5 ms` average RTT.
4. **Run Single-Stream & Parallel HTTPS Download/Upload Benchmarks**:
   Execute the `curl --interface uesimtun0` commands in [Section 3.22](#322-end-to-end-5g-user-plane-speedtest-simulated-ue) against `https://speed.cloudflare.com/__down` and `https://speed.cloudflare.com/__up`. Always pass `--interface uesimtun0` so traffic is forced into the 5G PDU session tunnel rather than the pod's management `eth0` interface.
5. **Confirm UPF `ogstun` Packet/Byte Counter Increment**:
   Re-run `kubectl -n open5gs exec open5gs-upf-0 -c upfd -- ip -s link show ogstun` and confirm `RX` (uplink from UE) and `TX` (downlink to UE) byte counters increased by the full benchmark payload volume with `0` interface errors.
