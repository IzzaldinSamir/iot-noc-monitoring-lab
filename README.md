# 📡 IoT & NOC Operations Lab

![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white) ![Grafana](https://img.shields.io/badge/grafana-%23F46800.svg?style=for-the-badge&logo=grafana&logoColor=white) ![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=Prometheus&logoColor=white) ![Bash](https://img.shields.io/badge/bash-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)

A containerized lab designed for **Network Operations Center (NOC)** and **L2 Support** engineers to practice monitoring, health-checking, and troubleshooting IoT packet-core infrastructure.

## 🏗️ Architecture
This lab uses Docker Compose to deploy a complete, production-style monitoring stack:
1. **Eclipse Mosquitto (MQTT):** The core IoT message broker handling device telemetry on TCP `1883` and WebSockets on `9001`.
2. **Mosquitto-Exporter:** Translates raw MQTT TCP metrics into HTTP metrics for Prometheus.
3. **cAdvisor:** Monitors deep container-level metrics (CPU, RAM, network limits) for the entire stack.
4. **Prometheus:** Time-series database actively scraping the Mosquitto Exporter and cAdvisor.
5. **Grafana:** Visual dashboard for the NOC team to monitor active connections, resource exhaustion, and packet drops.

## 📂 Included Resources
* `docker-compose.yml` - Defines the 5-container infrastructure stack.
* `mosquitto.conf` - Enables TCP and WebSocket listeners for the IoT broker.
* `prometheus.yml` - Custom scrape configurations for the exporters.
* `iot-healthcheck.sh` - An automated Bash script to verify TCP port availability and HTTP status codes.
* `RUNBOOK.md` - An ITIL-compliant L2 Incident Response runbook detailing `tcpdump` and Wireshark workflows for MQTT disconnects.

## 🚀 How to Run
Ensure Docker and the Docker Compose plugin are installed on your Linux environment.

```bash
# Clone the repository
git clone https://github.com/IzzaldinSamir/iot-noc-monitoring-lab.git
cd iot-noc-monitoring-lab

# Spin up the infrastructure in detached mode
docker compose up -d

# Run the NOC health check script
chmod +x iot-healthcheck.sh
./iot-healthcheck.sh
```

## 🌐 Service Endpoints
| Service | Address |
| :--- | :--- |
| **Grafana** | `http://localhost:3000` |
| **Prometheus** | `http://localhost:9090` |
| **cAdvisor** | `http://localhost:8080` |
| **MQTT Broker** | `localhost:1883` (TCP) / `9001` (WS) |

*Author: Ezzulddin Al-Sammarraie*
