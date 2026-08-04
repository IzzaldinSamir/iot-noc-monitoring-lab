# IoT MQTT Incident Response Runbook

**Service:** IoT MQTT messaging and monitoring lab

**Audience:** NOC L1/L2 operators

**Primary signals:** Grafana, Prometheus, Alertmanager, container state, broker logs

This runbook maps each configured alert to a repeatable investigation. Commands assume they are run from the repository root.

## Severity guide

| Priority | Example | Initial action target |
|---|---|---|
| P1 | Broker unavailable and device traffic affected | Immediate |
| P2 | Telemetry silent, messages dropping, or a monitoring target down | Within 15 minutes |
| P3 | Configuration reload failure without service impact | Same working session |

Promote or lower severity based on actual client impact. An alert is evidence to investigate, not proof of root cause.

## Universal first response

1. Record alert name, start time, affected instance, and current impact.
2. Run the operator checks:

   ```bash
   ./iot-healthcheck.sh
   docker compose ps
   ```

3. Check active alerts and recent service logs:

   ```bash
   ./scripts/drill.sh status
   docker compose logs --since=15m --tail=200 mosquitto mosquitto-exporter prometheus
   ```

4. Check whether a deployment, configuration edit, host restart, or resource event occurred near the alert start time.
5. Change one variable at a time, record the result, and confirm recovery in both the service and monitoring plane.

## MosquittoBrokerUnavailable

**Meaning:** The exporter reports `mosquitto_up == 0` for at least 30 seconds.

### Triage

```bash
docker compose ps mosquitto mosquitto-exporter
docker compose logs --since=10m --tail=200 mosquitto mosquitto-exporter
docker compose exec -T mosquitto \
  mosquitto_sub -h 127.0.0.1 -p 1883 -t '$SYS/broker/version' -C 1 -W 5
```

Interpretation:

- Mosquitto stopped or unhealthy: inspect its logs and configuration first.
- Mosquitto healthy but exporter disconnected: inspect service-network resolution and exporter logs.
- Local MQTT test works but remote clients fail: check host binding, firewall, routing, and client credentials/TLS settings.

### Recovery

```bash
docker compose up -d mosquitto mosquitto-exporter device-simulator
./iot-healthcheck.sh
```

Do not treat a container restart alone as root cause. Preserve logs and identify why the process stopped, became unhealthy, or lost network reachability.

### Escalate with

- Mosquitto and exporter logs covering five minutes before and after the failure
- `docker compose ps` output and container restart counts
- MQTT client error/CONNACK details
- Packet capture when transport or protocol behaviour is unclear

## TelemetryTrafficSilent

**Meaning:** The broker's one-minute inbound PUBLISH rate stays below `0.05` messages/s for the two-minute alert duration.

### Triage

```bash
docker compose ps device-simulator mosquitto
docker compose logs --since=10m --tail=200 device-simulator mosquitto

docker compose exec -T mosquitto \
  mosquitto_sub -h 127.0.0.1 -p 1883 -t 'iot/site-a/+/telemetry' -C 1 -W 10 -v
```

Then separate the path into three checks:

1. **Publisher:** Is the simulator or real device running and resolving the broker address?
2. **Transport/broker:** Can it establish TCP and receive a successful MQTT CONNACK?
3. **Topic flow:** Is it publishing the expected topic, QoS, and payload at the expected cadence?

### Recovery

```bash
docker compose up -d device-simulator
```

Confirm new messages with `mosquitto_sub`, then verify the Prometheus receive rate rises and the alert resolves.

## MonitoringTargetDown

**Meaning:** Prometheus cannot scrape one target for more than one minute.

### Triage

Open <http://localhost:9090/targets> and note the target's last scrape error.

```bash
docker compose ps prometheus mosquitto-exporter cadvisor alertmanager
docker compose logs --since=10m --tail=200 prometheus <affected-service>
docker compose exec -T prometheus wget -qO- http://<affected-service>:<port>/metrics | head
```

For Alertmanager, use `/-/ready` instead of `/metrics` if checking readiness. Common causes are a stopped service, wrong DNS/service name, wrong port, slow response, or rejected configuration.

### Recovery

Correct the service-specific problem and confirm two successful scrapes on the Prometheus targets page. If Prometheus itself is unhealthy, validate configuration before restarting it:

```bash
make validate
docker compose up -d prometheus
```

## MosquittoDroppedMessages

**Meaning:** Mosquitto reports a non-zero one-minute dropped-publish rate for at least one minute.

### Triage

Inspect message load, connected clients, container CPU/memory, and broker logs in the same time window.

```bash
docker compose logs --since=15m --tail=200 mosquitto
docker stats --no-stream
```

Check for:

- Slow or disconnected subscribers with queued messages
- A sudden publisher-rate increase
- Memory or CPU pressure
- QoS/inflight limits and oversized payloads
- Network loss or repeated reconnects

### Recovery

Reduce the publisher rate or isolate the malfunctioning client first. Change broker queue/inflight limits only after measuring the workload and understanding the delivery guarantees; increasing limits can move the failure from drops to memory exhaustion.

## PrometheusConfigReloadFailed

**Meaning:** Prometheus has reported an unsuccessful configuration reload for five minutes.

### Triage and recovery

```bash
docker compose logs --since=15m --tail=200 prometheus
make validate
```

Fix the reported YAML, rule syntax, or file-path error. Recreate Prometheus after validation passes:

```bash
docker compose up -d --force-recreate prometheus
```

Confirm `prometheus_config_last_reload_successful` returns `1`.

## Packet capture procedure

Use packet capture only when logs and metrics cannot distinguish transport from protocol failure.

```bash
sudo tcpdump -i any -nn 'tcp port 1883' \
  -w /tmp/iot-noc-mqtt-incident.pcap
```

Reproduce one connection attempt, stop capture with `Ctrl+C`, and inspect in Wireshark with:

```text
mqtt || tcp.port == 1883
```

Verify in order:

1. TCP SYN, SYN/ACK, ACK
2. MQTT CONNECT from client
3. MQTT CONNACK from broker
4. PUBLISH/PUBACK behaviour for QoS 1
5. FIN/RST direction and retransmissions

Port `1883` is plaintext in this lab, so a capture contains MQTT topics and payloads. Handle production captures as sensitive data and use a narrow time/host filter.

## Post-incident record

Capture the following before closure:

- Detection time, acknowledgement time, recovery time, and total duration
- User/device impact and affected topics or services
- Root cause and contributing factors
- Evidence used to confirm the cause
- Recovery action and proof of restored service
- Follow-up owner and due date for any prevention work

After recovery, run `make smoke` to verify endpoints, monitoring configuration, dashboard provisioning, and an end-to-end MQTT round trip.
