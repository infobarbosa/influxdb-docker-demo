from influxdb_client import InfluxDBClient

# Configurações do InfluxDB
url = "http://localhost:8086"
token = "3y1c3NnlmA1kA061YlROSO0gE5a1ppH_1Ig5HSMCsCX3VKF6zkrBwAtC-Hr6c_TTU8B9kwYOPphDq6hwyw5tLw=="
org = "infobarbosa"
bucket = "ecommerce"

# Criar o cliente do InfluxDB
client = InfluxDBClient(url=url, token=token, org=org)

# Consulta para sumarizar pedidos por minuto nos últimos 30 minutos, agrupando por departamento
query = f'''
from(bucket: "{bucket}")
  |> range(start: -30m)
  |> filter(fn: (r) => r._measurement == "pedidos")
  |> filter(fn: (r) => r._field == "quantidade")
  |> aggregateWindow(every: 1m, fn: sum, createEmpty: false)
  |> group(columns: ["_time", "produto"])
  |> yield(name: "sum")
'''

# Executar a consulta
query_api = client.query_api()
result = query_api.query(query)
print(type(result))

print("---")

# Processar os resultados
summary = []
for table in result:
    for record in table.records:
        summary.append({
            "time": record.get_time(),
            "produto": record.values.get("produto"),
            "quantidade": record.get_value(),
        })

# Exibir a sumarização
import pandas as pd

df = pd.DataFrame(summary)
print(df)

# Fechar o cliente
client.close()
