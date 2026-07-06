"""
Sumariza pedidos por minuto (últimos 30 minutos), agrupando por produto.

Versão InfluxDB 3: consulta em SQL padrão (DataFusion) via /api/v3/query_sql.
Substitui a versão antiga em Flux (aggregateWindow) do InfluxDB 2.x.
A função date_bin() é o equivalente SQL ao aggregateWindow do Flux.

Uso:
    export INFLUXDB_URL=http://localhost:8181   # opcional
    export INFLUXDB_DATABASE=ecommerce          # opcional
    python3 produtos_por_minuto.py
"""
import os

import pandas as pd
import requests

INFLUXDB_URL = os.getenv("INFLUXDB_URL", "http://localhost:8181")
DATABASE = os.getenv("INFLUXDB_DATABASE", "ecommerce")
TOKEN = os.getenv("INFLUXDB_TOKEN")  # opcional; None em ambiente --without-auth

sql = """
SELECT
  date_bin(INTERVAL '1 minute', time) AS minuto,
  produto,
  SUM(quantidade) AS quantidade
FROM pedidos
WHERE time >= now() - INTERVAL '30 minutes'
GROUP BY minuto, produto
ORDER BY minuto, produto
"""

headers = {}
if TOKEN:
    headers["Authorization"] = f"Bearer {TOKEN}"

resp = requests.get(
    f"{INFLUXDB_URL}/api/v3/query_sql",
    params={"db": DATABASE, "q": sql, "format": "json"},
    headers=headers,
    timeout=30,
)
resp.raise_for_status()

df = pd.DataFrame(resp.json())
print(df)
