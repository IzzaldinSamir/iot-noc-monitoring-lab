#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./scripts/drill.sh COMMAND

Commands:
  traffic-stop   Stop simulated device traffic
  broker-outage  Stop the MQTT broker
  recover        Restore the broker and simulator
  status         Show current container and alert state
EOF
}

command="${1:-}"
case "$command" in
    traffic-stop)
        docker compose stop device-simulator
        cat <<'EOF'
Traffic stopped. TelemetryTrafficSilent should move to firing after roughly
three minutes (one-minute moving average plus two-minute `for` duration).
Watch: http://127.0.0.1:9093
Recover with: ./scripts/drill.sh recover
EOF
        ;;
    broker-outage)
        docker compose stop mosquitto
        cat <<'EOF'
Broker stopped. MosquittoBrokerUnavailable should fire after 30 seconds, and
the Mosquitto scrape target may also fail while the exporter reconnects.
Watch: http://127.0.0.1:9093
Recover with: ./scripts/drill.sh recover
EOF
        ;;
    recover)
        docker compose up -d mosquitto mosquitto-exporter device-simulator
        echo 'Recovery started. Run ./iot-healthcheck.sh after services settle.'
        ;;
    status)
        docker compose ps
        echo
        curl --fail --silent --show-error \
            'http://127.0.0.1:9090/api/v1/alerts' |
            jq -r '.data.alerts[]? | "\(.labels.alertname) [\(.state)] \(.annotations.summary)"'
        ;;
    -h|--help)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
