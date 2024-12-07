import requests
import random
import time

produtos = ["TV", "GELADEIRA", "TV", "HOMETHEATER", "COMPUTADOR", "MONITOR", "TABLET", "SOUNDBAR", "CELULAR", "NOTEBOOK", "MICROONDAS"]	
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
    "MICROONDAS": "ELETRODOMESTICOS"
}
url = "http://localhost:8086/api/v2/write?org=infobarbosa&bucket=ecommerce&precision=ns"
headers = {
    "Authorization": "Token 3y1c3NnlmA1kA061YlROSO0gE5a1ppH_1Ig5HSMCsCX3VKF6zkrBwAtC-Hr6c_TTU8B9kwYOPphDq6hwyw5tLw==",
    "Content-Type": "text/plain; charset=utf-8",
    "Accept": "application/json"
}

while True:
    for pais in ["BR", "US", "AU"]:
        produto = random.choice(produtos)
        departamento = departamentos[produto]
        data = f"pedidos,produto={produto},departamento={departamento},pais={pais} quantidade={random.randint(0, 9)} {int(time.time() * 1e9)}"