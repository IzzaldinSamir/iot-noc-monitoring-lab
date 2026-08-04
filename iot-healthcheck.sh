#!/bin/bash
# NOC IoT Infrastructure Health Check Script

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Starting NOC Infrastructure Health Check..."
echo "-------------------------------------------"

# Check Grafana (HTTP)
GRAFANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)
if [ "$GRAFANA_STATUS" -eq 200 ] || [ "$GRAFANA_STATUS" -eq 302 ]; then
    echo -e "[ ${GREEN}OK${NC} ] Grafana Dashboard is ONLINE."
else
    echo -e "[ ${RED}FAIL${NC} ] Grafana Dashboard is OFFLINE or unreachable."
fi

# Check Prometheus (HTTP)
PROM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090)
if [ "$PROM_STATUS" -eq 200 ] || [ "$PROM_STATUS" -eq 302 ]; then
    echo -e "[ ${GREEN}OK${NC} ] Prometheus Time-Series DB is ONLINE."
else
    echo -e "[ ${RED}FAIL${NC} ] Prometheus Time-Series DB is OFFLINE."
fi

# Check MQTT Broker (TCP Port 1883)
if nc -z localhost 1883 2>/dev/null; then
    echo -e "[ ${GREEN}OK${NC} ] MQTT Broker (IoT) is accepting connections on port 1883."
else
    echo -e "[ ${RED}FAIL${NC} ] MQTT Broker is OFFLINE or port 1883 is closed."
fi

echo "-------------------------------------------"
echo "Health check complete."