"""
Produtor de pedidos para o InfluxDB 3 (equivalente em Python ao pedidos.sh).

Escreve data points continuamente no measurement `pedidos` usando o endpoint
HTTP nativo do InfluxDB 3: /api/v3/write_lp (Line Protocol).

Diferenças em relação à versão antiga (InfluxDB 2.x):
  - Porta 8181 (era 8086).
  - Endpoint /api/v3/write_lp?db=... (era /api/v2/write?org=...&bucket=...).
  - Sem token hardcoded. No InfluxDB 3 Core deste laboratório o servidor sobe
    com --without-auth. Em ambientes com autenticação, exporte INFLUXDB_TOKEN.

Uso:
    export INFLUXDB_URL=http://localhost:8181   # opcional
    export INFLUXDB_DATABASE=ecommerce          # opcional
    python3 pedidos.py
"""
import os
import random
import time

import requests

INFLUXDB_URL = os.getenv("INFLUXDB_URL", "http://localhost:8181")
DATABASE = os.getenv("INFLUXDB_DATABASE", "ecommerce")
TOKEN = os.getenv("INFLUXDB_TOKEN")  # opcional; None em ambiente --without-auth

produtos = [
    "TV", "GELADEIRA", "HOMETHEATER", "COMPUTADOR", "MONITOR",
    "TABLET", "SOUNDBAR", "CELULAR", "NOTEBOOK", "MICROONDAS",
]
departamentos = {
    "TV": "ELETRONICOS",
    "GELADEIRA": "ELETRODOMESTICOS",
    "HOMETHEATER": "ELETRONICOS",
    "COMPUTADOR": "INFORMATICA",
    "MONITOR": "INFORMATICA",
    "TABLET": "INFORMATICA",
    "SOUNDBAR": "ELETRONICOS",
    "CELULAR": "ELETRONICOS",
    "NOTEBOOK": "INFORMATICA",
    "MICROONDAS": "ELETRODOMESTICOS",
}
paises = ["BR", "US", "AU"]

write_url = f"{INFLUXDB_URL}/api/v3/write_lp"
headers = {"Content-Type": "text/plain; charset=utf-8"}
if TOKEN:
    headers["Authorization"] = f"Bearer {TOKEN}"

print(f"Iniciando produtor de pedidos -> {write_url}?db={DATABASE}")

while True:
    linhas = []
    for pais in paises:
        produto = random.choice(produtos)
        departamento = departamentos[produto]
        quantidade = random.randint(1, 5)
        preco = random.randint(500, 5000)
        # measurement,tag=... field=...  (timestamp omitido = instante do servidor)
        # Sem sufixo 'i': os fields são float, compatíveis com o produtor pedidos.sh
        # e com o schema já existente da tabela `pedidos`.
        linhas.append(
            f"pedidos,produto={produto},departamento={departamento},pais={pais} "
            f"quantidade={quantidade},preco={preco}"
        )

    body = "\n".join(linhas)
    try:
        resp = requests.post(
            write_url,
            params={"db": DATABASE, "precision": "ns"},
            headers=headers,
            data=body,
            timeout=5,
        )
        resp.raise_for_status()
    except requests.RequestException as e:
        print(f"[erro] falha ao escrever: {e}")

    time.sleep(1)
