# Implementation Plan & Architectural Review: Open5GS 5GS + EPC Blueprint on Google Cloud Platform

## 1. Goal & Scope
Design, implement, review, and validate an enterprise-grade **Open5GS 5G Standalone (5G SA) + 4G EPC CUPS Deployment Architecture Blueprint** running **100% within a Google Cloud Public Region**, accompanied by reference Terraform infrastructure templates, Kubernetes (GKE) deployment manifests, an end-to-end 5GS RAN/UE Simulation Suite, and a Zero-Trust Network Management System (NMS).

### Key Objectives
1. **100% Open5GS Component Coverage**: Map every daemon (`NRF`, `SCP`, `SEPP`, `AMF`, `SMF+PGW-C`, `UPF+PGW-U`, `AUSF`, `UDM`, `UDR`, `PCF`, `NSSF`, `BSF`, `MME`, `HSS`, `PCRF`, `SGW-C`, `SGW-U`), protocol stack (`freeDiameter`, `libogsmetrics`), CLI utility (`open5gs-dbctl`), and management portal (`open5gs-webui`) to native Google Cloud services.
2. **Database & In-Memory Architecture**: Evaluate and configure **Cloud Firestore Enterprise with MongoDB Compatibility** (contrasted against MongoDB Atlas on GCP, Percona on GKE Hyperdisk, and AlloyDB/Cloud Spanner) and **Cloud Memorystore for Valkey / Redis Cluster** (for NMS session state, policy caching, and 3GPP UDSF extensions).
3. **End-to-End 5GS Simulation**: Provide a self-contained, in-cluster 5G SA RAN (`gNodeB`) and `UE` simulator (`UERANSIM` `nr-gnb` & `nr-ue` + Open5GS built-in `meson test` conformance runner) using GKE Dataplane V2 Multi-Networking.
4. **Transparent Technical Limitations Analysis**: Document all software and cloud infrastructure limitations (kernel `ogstun` context-switch throughput ceiling, GCP L4 Load Balancer SCTP constraints on `N2`/`S1-MME`, local C heap `ogs_pool` state on pod restart, public region WAN backhaul latency, VPC anti-spoofing on `N6`, Firestore index nuances, and external IMS/CHF integration).

---

## 2. Walkthrough & Principal Architect Review Matrix

| Blueprint Section | Coverage & Architectural Walkthrough | Review Status |
| :--- | :--- | :--- |
| **1.A – 1.B: Executive Summary & End-to-End Reference Architecture** | Defines a 100% Google Cloud Public Region (`us-central1`) deployment for Open5GS (`v2.7+`), bridging 3GPP Release-17/18 HTTP/2 SBA, CUPS (`N4`/`Sxa` PFCP), `N2`/`S1-MME` SCTP, `N3`/`S1-U` GTP-U (`MTU 8896`), and `N26` 5GS-EPS interworking across 5 isolated VPC networks (`vpc-sbi-mgmt`, `vpc-n2-signaling`, `vpc-n3-userplane`, `vpc-n4-pfcp`, `vpc-n6-dn`). | **Verified & Approved** |
| **1.C: 100% Open5GS Component-to-GCP Mapping** | Maps all **17 Open5GS C daemons** (12 5GC + 5 EPC/CUPS), **`freeDiameter`**, **`open5gs-dbctl`**, **`open5gs-webui`**, **`libogsmetrics`**, and **Simulation (`UERANSIM` + `meson test`)** to native GCP services. | **Verified & Approved** |
| **1.D: Service Selection & Decision Matrix** | Evaluates **GKE Standard vs. Autopilot** (why `ogstun` `/dev/net/tun`, `CAP_NET_ADMIN`, and Dataplane V2 Multi-NIC require GKE Standard), **Cloud Firestore (MongoDB Compatibility)** vs. **MongoDB Atlas** vs. **Percona on GKE Hyperdisk** vs. **AlloyDB/Spanner**, and **Cloud Memorystore for Valkey/Redis** vs. `ogs_pool` local C heap state. | **Verified & Approved** |
| **1.E – 1.G: Call Flows, NMS, & 5GS Simulation Architecture** | Documents the 3GPP Registration & PDU Session sequence, the Zero-Trust NMS stack (`WebUI` behind `IAP` + `Cloud Armor`, `GMP` scraping `:9090/metrics`, `Cloud Logging`, `GKE Config Sync`), and the 4-tier Simulation strategy (`meson test`, `UERANSIM`, `PacketRusher`, `srsRAN + ZeroMQ`). | **Verified & Approved** |
| **2: 7-Phase GCP Deployment Guide** | Provides step-by-step `gcloud` and `kubectl` commands for VPC creation, firewall rules, Firestore/Memorystore provisioning, GKE Multi-NIC node pool creation, NF rollout, NMS setup, and E2E simulation verification. | **Verified & Remediated** *(Fixed CLI flag typo & aligned nodeSelector labels across Phase 1, 3, & 4).* |
| **3: Comprehensive Limitations & Mitigations (1–7)** | Details 7 critical limitations: (1) Kernel `ogstun` context-switch bottleneck (~2–5 Gbps), (2) GCP Load Balancer lack of native `SCTP` support on `N2`/`S1-MME`, (3) In-memory `ogs_pool` UE state on pod restart vs. 3GPP `UDSF`, (4) Public region WAN latency on `N3`, (5) GCP VPC anti-spoofing on `N6`, (6) Firestore MongoDB compatibility index nuances, and (7) External IMS (`VoNR`) & Charging (`CHF`) requirements. | **Verified & Approved** |
| **4 – 6: Capacity Sizing, Security Guardrails, & Disclaimers** | Provides baseline sizing and monthly GCP cost estimates (~$1,380–$1,450/mo for 10k active UEs / 2 Gbps user plane), SBI mTLS, KMS CMEK for `Ki`/`OPc`, and CE boundaries. | **Verified & Remediated** *(Updated sizing table to include 4G EPC CUPS / N26 and in-cluster simulation workloads).* |

---

## 3. Audit Findings & Applied Remediations

1. **Finding 1 (Repository Completeness)**: Synchronized `implementation_plan.md` with the expanded repository scope (`k8s/04-ueransim-ran-ue-simulator.yaml`, `k8s/05-epc-cups-and-interworking.yaml`, `README.md`, and `.gitignore`) and persisted it directly in the project root (`implementation_plan.md`).
2. **Finding 2 (Kubernetes Service Discovery & Governing Headless Services)**: Added explicit `Service` definitions for all SBA NFs (`open5gs-udm`, `open5gs-ausf`, `open5gs-pcf`, `open5gs-nssf`, `open5gs-bsf`, `open5gs-sepp`) and governing `StatefulSet` services (`open5gs-amf`, `open5gs-smf`, `open5gs-upf`, `open5gs-sgwu`) across `k8s/01-control-plane-sba.yaml`, `k8s/02-upf-user-plane.yaml`, and `k8s/05-epc-cups-and-interworking.yaml`.
3. **Finding 3 (CLI Runbook Alignment in `design_blueprint.md`)**:
   - Updated Phase 1 firewall rule CLI command (`allow-n2-s1mme-sctp`) to include `sctp:38412,36412,29118` and `udp:2123`.
   - Updated Phase 3 Memorystore CLI command to use `gcloud redis instances create open5gs-inmemory-cache`.
   - Fixed `-- image-type=UBUNTU_CONTAINERD` $\rightarrow$ `--image-type=UBUNTU_CONTAINERD`, added `--can-ip-forward`, and aligned `--node-labels=5g-plane=control-plane-sba` and `--node-labels=5g-plane=multinic-dataplane` in Phase 4.
4. **Finding 4 (Capacity Sizing Update)**: Included the 4G EPC CUPS / N26 (`MME`, `HSS`, `PCRF`, `SGW-C`, `SGW-U`) and in-cluster `UERANSIM` simulation pods in Section 4.A of `design_blueprint.md`.

---

## 4. Repository Deliverables Inventory

| File Path | Category | Description |
| :--- | :--- | :--- |
| [README.md](README.md) | Documentation | Architecture overview, component mapping summary, repository structure, and 4-step deployment & simulation quickstart. |
| [design_blueprint.md](design_blueprint.md) | Architecture Blueprint | Principal Architect 5GS + EPC Deployment Blueprint on GCP (Architecture, Decision Matrix, 7-Phase Runbook, 7 Limitations, Sizing & Security). |
| [implementation_plan.md](implementation_plan.md) | Engineering Plan & Review | Technical implementation plan, section-by-section walkthrough, audit findings, and verification procedures. |
| [.gitignore](.gitignore) | Security Guardrails | Excludes Terraform state/vars (`*.tfstate`, `*.tfvars`), GCP credentials, kubeconfigs, SIM keys (`Ki`/`OPc`), TLS private keys (`*.pem`, `*.key`), and PCAPs. |
| [terraform/variables.tf](terraform/variables.tf) | Terraform IaC | Input variables for `project_id`, `region`, `zones`, `ran_cidr`, `ue_pool_cidr`, `plmn_mcc`, and `plmn_mnc`. |
| [terraform/main.tf](terraform/main.tf) | Terraform IaC | Multi-VPC fabric (`vpc-sbi-mgmt`, `vpc-n2-signaling`, `vpc-n3-userplane`, `vpc-n4-pfcp`, `vpc-n6-dn`), 3GPP firewall rules, GKE Standard Dataplane V2 + Multi-NIC node pools, Cloud Firestore (`MONGODB_COMPATIBLE`), and Cloud Memorystore. |
| [k8s/00-namespace-and-networks.yaml](k8s/00-namespace-and-networks.yaml) | GKE Multi-Networking | `open5gs` namespace + 8 `GKENetworkParamSet` and `Network` CRDs for `N2`, `N3`, `N4`, and `N6`. |
| [k8s/01-control-plane-sba.yaml](k8s/01-control-plane-sba.yaml) | 5G SA Control Plane | Deployments, StatefulSets, and Services for `NRF`, `SCP`, `UDR`, `UDM`, `AUSF`, `PCF`, `NSSF`, `BSF`, `SEPP`, `AMF`, `SMF` + `PodMonitoring` CRD for GMP. |
| [k8s/02-upf-user-plane.yaml](k8s/02-upf-user-plane.yaml) | 5G User Plane (CUPS) | Multi-NIC `open5gs-upf` StatefulSet + headless Service + `ogstun` init container + `PodDisruptionBudget`. |
| [k8s/03-nms-webui-iap.yaml](k8s/03-nms-webui-iap.yaml) | NMS Portal & Security | `open5gs-webui` Deployment, Service, GCE Ingress, and `BackendConfig` for Cloud Armor + Identity-Aware Proxy (IAP). |
| [k8s/04-ueransim-ran-ue-simulator.yaml](k8s/04-ueransim-ran-ue-simulator.yaml) | 5GS Simulation Suite | Multi-NIC `ueransim-gnb` + `ueransim-ue` (`uesimtun0`) + `open5gs-native-5gc-conformance-test` Job (`meson test`). |
| [k8s/05-epc-cups-and-interworking.yaml](k8s/05-epc-cups-and-interworking.yaml) | 4G EPC CUPS & N26 | `MME`, `HSS`, `PCRF`, `SGW-C`, `SGW-U` workloads & Services + `open5gs-dbctl-subscriber-seed` CLI provisioning Job. |

---

## 5. Verification Plan

### Automated Verification
Run the schema and service-binding check across all Kubernetes manifests:
```bash
python3 -c '
import yaml, glob
services, statefulsets, deployments = set(), set(), set()
for path in sorted(glob.glob("k8s/*.yaml")):
    with open(path) as f:
        docs = [d for d in yaml.safe_load_all(f) if d is not None]
    for d in docs:
        if d["kind"] == "Service": services.add(d["metadata"]["name"])
        elif d["kind"] == "StatefulSet": statefulsets.add(d["spec"]["serviceName"])
        elif d["kind"] == "Deployment": deployments.add(d["metadata"]["name"])
    print(f"OK: {path} ({len(docs)} resources)")
assert statefulsets.issubset(services), f"Missing StatefulSet services: {statefulsets - services}"
print("All StatefulSet governing Services verified:", sorted(statefulsets))
'
```
