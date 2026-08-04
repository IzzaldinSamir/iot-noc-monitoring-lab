#!/bin/sh
set -eu

broker_host="${BROKER_HOST:-mosquitto}"
broker_port="${BROKER_PORT:-1883}"
device_count="${DEVICE_COUNT:-8}"
publish_interval="${PUBLISH_INTERVAL:-5}"
status_topic="noc/lab/simulator/status"

is_positive_integer() {
    case "$1" in
        ''|*[!0-9]*|0) return 1 ;;
        *) return 0 ;;
    esac
}

if ! is_positive_integer "$device_count" || ! is_positive_integer "$publish_interval"; then
    echo "DEVICE_COUNT and PUBLISH_INTERVAL must be positive integers." >&2
    exit 2
fi

publish_status() {
    status="$1"
    mosquitto_pub \
        -h "$broker_host" \
        -p "$broker_port" \
        -q 1 \
        -r \
        -t "$status_topic" \
        -m "{\"status\":\"${status}\",\"device_count\":${device_count}}"
}

shutdown() {
    publish_status offline >/dev/null 2>&1 || true
}
trap shutdown EXIT
trap 'exit 0' INT TERM

echo "Waiting for MQTT broker at ${broker_host}:${broker_port}..."
until publish_status online >/dev/null 2>&1; do
    sleep 2
done

echo "Publishing telemetry for ${device_count} simulated devices every ${publish_interval}s."
sequence=0

while :; do
    sequence=$((sequence + 1))
    device=1
    timestamp="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

    while [ "$device" -le "$device_count" ]; do
        temperature_tenths=$((205 + (sequence * 3 + device * 7) % 95))
        temperature_whole=$((temperature_tenths / 10))
        temperature_decimal=$((temperature_tenths % 10))
        humidity=$((38 + (sequence + device * 5) % 35))
        battery=$((100 - (sequence / 120 + device) % 25))
        signal_dbm=$((-45 - (sequence + device * 3) % 35))
        device_id="$(printf 'sensor-%03d' "$device")"
        topic="iot/site-a/${device_id}/telemetry"
        payload="$(printf \
            '{\"device_id\":\"%s\",\"timestamp\":\"%s\",\"sequence\":%d,\"temperature_c\":%d.%d,\"humidity_pct\":%d,\"battery_pct\":%d,\"signal_dbm\":%d}' \
            "$device_id" "$timestamp" "$sequence" "$temperature_whole" \
            "$temperature_decimal" "$humidity" "$battery" "$signal_dbm")"

        mosquitto_pub \
            -h "$broker_host" \
            -p "$broker_port" \
            -q 1 \
            -t "$topic" \
            -m "$payload"

        device=$((device + 1))
    done

    sleep "$publish_interval"
done
