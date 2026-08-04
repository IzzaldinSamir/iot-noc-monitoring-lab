#!/usr/bin/env bash
set -uo pipefail

host="${NOC_HOST:-127.0.0.1}"
timeout_seconds="${TIMEOUT_SECONDS:-5}"
failures=0

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    green='\033[0;32m'
    red='\033[0;31m'
    reset='\033[0m'
else
    green=''
    red=''
    reset=''
fi

usage() {
    cat <<'EOF'
Usage: ./iot-healthcheck.sh [--host HOST] [--timeout SECONDS]

Checks every lab endpoint, the MQTT TCP listener, and Prometheus target state.
The script exits non-zero when any check fails, so it can be used by CI or cron.
EOF
}

while (($# > 0)); do
    case "$1" in
        --host)
            [[ $# -ge 2 ]] || { echo "--host requires a value" >&2; exit 2; }
            host="$2"
            shift 2
            ;;
        --timeout)
            [[ $# -ge 2 ]] || { echo "--timeout requires a value" >&2; exit 2; }
            timeout_seconds="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ ! "$timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
    echo "Timeout must be a positive integer." >&2
    exit 2
fi

for command in curl jq timeout; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Missing dependency: $command" >&2
        exit 2
    fi
done

pass() {
    printf '[ %bOK%b ] %s\n' "$green" "$reset" "$1"
}

fail() {
    printf '[ %bFAIL%b ] %s\n' "$red" "$reset" "$1"
    failures=$((failures + 1))
}

check_http() {
    local label="$1"
    local url="$2"

    if curl --fail --silent --show-error --max-time "$timeout_seconds" "$url" >/dev/null; then
        pass "$label"
    else
        fail "$label"
    fi
}

check_tcp() {
    local label="$1"
    local port="$2"

    # Positional parameters expand inside the child Bash process, not here.
    # shellcheck disable=SC2016
    if timeout "$timeout_seconds" bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$host" "$port" 2>/dev/null; then
        pass "$label"
    else
        fail "$label"
    fi
}

printf 'IoT NOC lab health check (%s)\n\n' "$host"

check_http 'Grafana API is healthy' "http://${host}:3000/api/health"
check_http 'Prometheus is ready' "http://${host}:9090/-/ready"
check_http 'Alertmanager is ready' "http://${host}:9093/-/ready"
check_http 'cAdvisor is healthy' "http://${host}:8080/healthz"
check_http 'Mosquitto exporter is healthy' "http://${host}:9344/healthz"
check_tcp 'MQTT broker accepts TCP connections' 1883
check_tcp 'MQTT WebSocket listener accepts TCP connections' 9001

targets_url="http://${host}:9090/api/v1/query"
targets_query='up{job=~"prometheus|mosquitto|cadvisor|alertmanager"}'
if curl --fail --silent --show-error --max-time "$timeout_seconds" \
    --get --data-urlencode "query=${targets_query}" "$targets_url" |
    jq -e '
        .status == "success" and
        (.data.result | length) == 4 and
        all(.data.result[]; .value[1] == "1")
    ' >/dev/null; then
    pass 'All four Prometheus scrape targets are up'
else
    fail 'One or more Prometheus scrape targets are down'
fi

printf '\n'
if ((failures == 0)); then
    printf '%bAll checks passed.%b\n' "$green" "$reset"
    exit 0
fi

printf '%b%d check(s) failed.%b\n' "$red" "$failures" "$reset"
exit 1
