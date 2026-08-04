#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

for command in docker jq; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "Missing dependency: $command" >&2
        exit 2
    }
done

echo 'Validating shell scripts...'
bash -n iot-healthcheck.sh scripts/smoke-test.sh scripts/validate.sh scripts/drill.sh
sh -n scripts/publish-telemetry.sh
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck iot-healthcheck.sh scripts/*.sh
else
    echo 'shellcheck is not installed; syntax checks completed, lint skipped.'
fi

echo 'Validating Docker Compose configuration...'
docker compose config --quiet

echo 'Validating Prometheus configuration and alert rules...'
docker run --rm --entrypoint /bin/promtool \
    -v "$root_dir/prometheus:/etc/prometheus:ro" \
    prom/prometheus:v3.13.2 \
    check config /etc/prometheus/prometheus.yml

docker run --rm --entrypoint /bin/promtool \
    -v "$root_dir/prometheus:/etc/prometheus:ro" \
    prom/prometheus:v3.13.2 \
    check rules /etc/prometheus/alert_rules.yml

docker run --rm --entrypoint /bin/promtool \
    -v "$root_dir/prometheus:/etc/prometheus:ro" \
    -w /etc/prometheus \
    prom/prometheus:v3.13.2 \
    test rules alert_tests.yml

echo 'Validating Alertmanager configuration...'
docker run --rm --entrypoint /bin/amtool \
    -v "$root_dir/alertmanager:/etc/alertmanager:ro" \
    prom/alertmanager:v0.33.1 \
    check-config /etc/alertmanager/alertmanager.yml \
    --enable-feature=utf8-strict-mode

echo 'Validating Grafana dashboard JSON...'
jq -e '.uid == "iot-noc-overview" and (.panels | length) >= 6' \
    grafana/dashboards/iot-noc-overview.json >/dev/null

echo 'All static validation checks passed.'
