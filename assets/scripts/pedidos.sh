#!/bin/sh
INFLUXDB_URL="${INFLUXDB_URL:-http://influxdb-demo:8181}"
DATABASE="${DATABASE:-ecommerce}"

produtos="TV GELADEIRA HOMETHEATER COMPUTADOR MONITOR TABLET SOUNDBAR CELULAR NOTEBOOK"
paises="BR US AU"
N_PRODUTOS=9
N_PAISES=3

get_item() {
    echo "$1" | cut -d' ' -f$(( ($2 % $3) + 1 ))
}

echo "Iniciando produtor de pedidos -> ${INFLUXDB_URL}"

while true; do
    produto=$(get_item "$produtos" $RANDOM $N_PRODUTOS)
    pais=$(get_item "$paises" $RANDOM $N_PAISES)
    quantidade=$(( (RANDOM % 5) + 1 ))
    preco=$(( (RANDOM % 5000) + 500 ))

    curl -sf -XPOST "${INFLUXDB_URL}/api/v3/write_lp?db=${DATABASE}&precision=s" \
        --data-binary "pedidos,produto=${produto},pais=${pais} quantidade=${quantidade},preco=${preco}" || true

    sleep 1
done
