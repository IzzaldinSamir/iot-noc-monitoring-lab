#!/usr/bin/env bash
set -euo pipefail

host="${NOC_HOST:-127.0.0.1}"
attempts="${SMOKE_TEST_ATTEMPTS:-24}"
received_file="$(mktemp)"
subscriber_pid=''

cleanup() {
    if [[ -n "$subscriber_pid" ]] && kill -0 "$subscriber_pid" 2>/dev/null; then
        kill "$subscriber_pid" 2>/dev/null || true
    fi
    rm -f "$received_file"
}
trap cleanup EXIT

for command in curl docker jq; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "Missing dependency: $command" >&2
        exit 2
    }
done

echo 'Waiting for the stack to become healthy...'
healthy=false
for ((attempt = 1; attempt <= attempts; attempt++)); do
    if ./iot-healthcheck.sh --host "$host" >/dev/null 2>&1; then
        healthy=true
        break
    fi
    sleep 5
done

if [[ "$healthy" != true ]]; then
    echo "Stack did not become healthy after $((attempts * 5)) seconds." >&2
    ./iot-healthcheck.sh --host "$host" || true
    exit 1
fi

echo 'Running an end-to-end MQTT publish/subscribe check...'
topic="noc/lab/smoke/$(date +%s)"
payload="smoke-ok-$(date +%s)"

docker compose exec -T mosquitto \
    mosquitto_sub -h 127.0.0.1 -p 1883 -t "$topic" -C 1 -W 10 \
    >"$received_file" &
subscriber_pid=$!
sleep 1
docker compose exec -T mosquitto \
    mosquitto_pub -h 127.0.0.1 -p 1883 -q 1 -t "$topic" -m "$payload"
wait "$subscriber_pid"
subscriber_pid=''
grep -Fxq "$payload" "$received_file"

echo 'Checking provisioned Grafana assets and Prometheus rules...'
curl --fail --silent --show-error \
    "http://${host}:3000/api/search?query=IoT%20NOC" |
    jq -e 'any(.[]; .uid == "iot-noc-overview")' >/dev/null

curl --fail --silent --show-error "http://${host}:9090/api/v1/rules" |
    jq -e '.status == "success" and (.data.groups | length) > 0' >/dev/null

echo 'Smoke test passed: endpoints, scrape targets, dashboard, rules, and MQTT round trip.'
