# 🚨 NOC Incident Response Runbook

## Scenario: IoT Devices Dropping Connections (MQTT Disconnects)

### 1. Initial Triage (L1)
* Run `./iot-healthcheck.sh` to verify if the Mosquitto MQTT container is actively accepting TCP connections.
* Check Grafana dashboards for a sudden drop in active connections or spiked CPU/RAM usage.

### 2. Deep Dive / Network Analysis (L2)
If the container is running but IoT devices cannot connect, we need to inspect the packet core flow.

**Step A: Verify Container Logs**
```bash
docker logs noc-iot-broker --tail 50