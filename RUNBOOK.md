# 🚨 NOC Incident Response Runbook

**Document Owner:** Network Operations Center (NOC) Tier 2
**Service:** IoT MQTT Message Broker
**Severity Level:** SEV-1 (Critical Infrastructure)

## 📌 Scenario: IoT Devices Dropping Connections (MQTT Disconnects)

### 1. Incident Detection & Initial Triage (L1)
* **Alert Source:** Prometheus/Grafana triggers an alert for `MQTT_Active_Connections < Threshold`.
* **Action:** Run `./iot-healthcheck.sh` to verify if the Mosquitto MQTT container is actively accepting TCP connections on port `1883`.
* **Action:** Check Grafana `cAdvisor` dashboards for sudden spikes in CPU/RAM usage that indicate resource exhaustion.

### 2. Deep Dive / Network Analysis (L2)
If the container is running but IoT devices cannot connect, inspect the network packet flow.

**Step A: Verify Container Logs**
Run the following command to check the last 50 logs:
`docker logs noc-iot-broker --tail 50`
*Look for: Authentication failures, memory allocation limits, or malformed packets.*

**Step B: Packet Capture (tcpdump)**
Capture traffic on the MQTT port to verify the 3-way TCP handshake and MQTT CONNECT payloads.
`sudo tcpdump -i any port 1883 -w /tmp/mqtt_drop_investigation.pcap`

**Step C: Wireshark Analysis**
* Download the `.pcap` file to your local machine.
* Filter by `mqtt` in Wireshark.
* Analyze `CONNACK` return codes (e.g., `0x05` Connection Refused, not authorized).

### 3. Resolution & Escalation
* **Network Issue:** Verify firewall/iptables rules preventing port 1883 access.
* **Resource Exhaustion:** Restart the container to flush memory: `docker compose restart mosquitto`.
* **Escalation:** If unresolved after 15 minutes, escalate to L3 Core Network Engineering with the attached `.pcap` file and system logs.

### 4. Post-Incident Review (PIR)
* Document root cause, time to resolution (TTR), and update this runbook if a new failure pattern is identified.
