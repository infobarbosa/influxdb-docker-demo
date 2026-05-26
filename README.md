# Armazenamento de Séries Temporais com InfluxDB 3

Author: Prof. Barbosa<br>
Contact: infobarbosa@gmail.com<br>
Github: [infobarbosa](https://github.com/infobarbosa)

O objetivo deste laboratório é oferecer ao aluno um ambiente de familiarização com o modelo de armazenamento de séries temporais utilizando **InfluxDB 3**.

## Introdução

[InfluxDB](https://docs.influxdata.com/influxdb3/core/) é um banco de dados de série temporal desenvolvido pela InfluxData. A versão 3 traz suporte nativo a **SQL**, tornando as consultas mais acessíveis a quem já conhece bancos de dados relacionais.<br>
> Fonte: [Wikipedia](https://en.wikipedia.org/wiki/InfluxDB)

## Line Protocol
<br>
O protocolo de linha (line protocol) do InfluxDB é um formato simples baseado em texto adotado para escrita de data points no banco de dados.
<br>

### Sintaxe

```
<measurement>[,<tag_key>=<tag_value>[,<tag_key>=<tag_value>]] <field_key>=<field_value>[,<field_key>=<field_value>] [<timestamp>]
``` 

Onde:
- `<measurement>` (obrigatório e case-sensitive) <br>
    - Tipo `string` que representa o nome da medida. 

- `<tag_key>=<tag_value>` (não obrigatório, porém case-sensitive) <br>
    - Tags representadas por pares chave-valor para o data point.<br> 
    - A relação entre chave e valor é representada pelo operador `=`.<br> 
    - Ambos chave e valor devem ser do tipo `string`.<br>
    - O protocolo suporta múltiplas ocorrências de tags.

- `<field_key>=<field_value>` (obrigatório e case-sensitive) <br>
    - Fields (campos) representados por pares chave-valor para o data point.<br>
    - Cada data point precisa ter pelo menos um field.<br>
    - Fields keys (chaves) devem ser do tipo `string`, field values (valores) podem ser dos tipos `Float`, `Integer`, `UInteger`, `String` e `Boolean`.

- `[<timestamp>]` é expresso em nanossegundos e não obrigatório.<br>
    > Caso não informado, o InfluxDB utiliza o timestamp interno do servidor.

**Exemplo**:
```
pedidos,produto=GELADEIRA quantidade=1,preco=2000 1668387574000000000
```

## Laboratório

### 1. Ambiente 
Este laboratório pode ser executado em qualquer estação de trabalho com docker disponível.<br>
Recomendo, porém, a execução em Linux.<br>
Caso você não tenha um à sua disposição, utilize o serviço **AWS Cloud9**. As instruções podem ser encontradas [aqui](https://github.com/infobarbosa/data-engineering-cloud9).


### 2. Setup (APENAS PARA AWS CLOUD9)
Baixe e execute o script de setup

```bash
wget https://raw.githubusercontent.com/infobarbosa/influxdb-docker-demo/main/assets/scripts/cloud9.sh

```

```bash
bash ./cloud9.sh

```

**Atenção!** <br>
Ao final da execução do script será disponibilizado um URL. Copie e guarde-o porque vamos utilizá-lo mais tarde neste laboratório.

Output esperado:
```
### Atualizando o sistema ###
...
Acesse o ambiente Cloud9 em: http://ec2-34-238-49-243.compute-1.amazonaws.com:8086

```

Caso precise recuperar o URL:
```
export CLOUD9_EC2_INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data//instance-id)
export CLOUD9_EC2_PUBLIC_DNS=$(aws ec2 describe-instances --instance-id $CLOUD9_EC2_INSTANCE_ID | jq -r .Reservations[0].Instances[0].NetworkInterfaces[0].Association.PublicDnsName)
echo "DNS público: $CLOUD9_EC2_PUBLIC_DNS"

```

### 3. Docker Compose

Por simplicidade, vamos utilizar o InfluxDB em um container baseado em *Docker*.<br>
#### Baixe o script `compose.yaml`
```bash
wget https://raw.githubusercontent.com/infobarbosa/influxdb-docker-demo/main/compose.yaml

```

```
ls -la compose.yaml

```

#### Inicialização
```
docker compose up -d

```

Este comando inicializa três serviços:
- **`influxdb`**: o banco de dados InfluxDB 3, acessível na porta `8086`.
- **`influxproducer`**: produtor de dados que insere pedidos simulados continuamente no banco `ecommerce`, permitindo visualizar dados em tempo real.
- **`grafana`**: plataforma de visualização de dashboards, acessível na porta `3000`. Explorada na seção bônus ao final do laboratório.

### 4. Criando o banco de dados

No InfluxDB 3, o equivalente ao *bucket* é o **database**. Após inicializar os containers, crie o banco `ecommerce`:

```bash
docker exec -it influxdb-demo influxdb3 create database ecommerce

```

> **Nota:** O produtor de dados (`influxproducer`) ficará em loop tentando escrever automaticamente assim que o banco existir.

---

### 5. `influxdb3 write`

O comando `influxdb3 write` escreve data points no InfluxDB via entrada padrão ou argumento direto.

#### Sintaxe

```
influxdb3 write --database <nome> "<line protocol>"
``` 

Maiores informações: https://docs.influxdata.com/influxdb3/core/reference/cli/influxdb3/write/

#### Exemplo 1 — Venda de uma geladeira
```bash
docker exec -it influxdb-demo influxdb3 write \
  --database ecommerce \
  "pedidos,produto=GELADEIRA,pais=BR quantidade=1,preco=2000 1668387574000000000"

```

#### Exemplo 2 — Venda sem timestamp
> O InfluxDB usará o instante atual do servidor.
```bash
docker exec -it influxdb-demo influxdb3 write \
  --database ecommerce \
  "pedidos,produto=TV,pais=US quantidade=2,preco=5000"

```

#### Exemplo 3 — Múltiplos data points
```bash
docker exec -it influxdb-demo influxdb3 write \
  --database ecommerce \
  "pedidos,produto=FOGAO,pais=BR quantidade=1,preco=1000 1668426060000000000
pedidos,produto=GELADEIRA,pais=AU quantidade=1,preco=2000 1668426081000000000
pedidos,produto=LAVADORA,pais=BR quantidade=1,preco=1000 1668426093000000000
pedidos,produto=FILTRO,pais=US quantidade=1,preco=500 1668426100000000000
pedidos,produto=TV,pais=BR quantidade=1,preco=5000 1668426107000000000"

```

---

### 6. `influxdb3 query` — SQL

No InfluxDB 3, as consultas são feitas em **SQL padrão**. O measurement (`pedidos`) é a tabela, tags e fields são colunas, e o timestamp fica na coluna `time`.

#### Sintaxe

```
influxdb3 query --database <nome> "<SQL>"
```

#### Exemplo 4 — Recuperar tudo

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT * FROM pedidos"

```

**Onde:**
- `SELECT *` — retorna todas as colunas.
- `FROM pedidos` — especifica o measurement (tabela).

---

#### Exemplo 5 — Filtrar por produto

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT * FROM pedidos WHERE produto = 'GELADEIRA'"

```

---

#### Exemplo 6 — Selecionar colunas específicas

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT time, produto, pais, quantidade, preco FROM pedidos ORDER BY time DESC LIMIT 20"

```

---

### 7. Especificando o período

Para filtrar por intervalo de tempo, use a coluna `time` na cláusula `WHERE`.

#### Exemplo 7 — Consulta para novembro de 2022

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT * FROM pedidos
   WHERE time >= '2022-11-01T00:00:00Z'
     AND time <  '2022-12-01T00:00:00Z'"

```

---

#### Exemplo 8 — Últimos 2 minutos

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT * FROM pedidos
   WHERE time >= now() - INTERVAL '2 minutes'
   ORDER BY time DESC"

```

> **Atenção:** Os data points inseridos com timestamp fixo em 2022 **não aparecerão** aqui. Apenas os inseridos sem timestamp (Exemplo 2) ou pelo produtor automático poderão aparecer.

---

#### Exemplo 9 — Últimos 2 minutos com colunas organizadas

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT time, produto, pais, quantidade, preco
   FROM pedidos
   WHERE time >= now() - INTERVAL '2 minutes'
   ORDER BY time DESC"

```

---

### 8. Agregações SQL

#### Exemplo 10 — Total de vendas por produto (últimos 30 minutos)

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT produto, SUM(quantidade) AS total_vendas
   FROM pedidos
   WHERE time >= now() - INTERVAL '30 minutes'
   GROUP BY produto
   ORDER BY total_vendas DESC"

```

---

#### Exemplo 11 — Vendas por produto e país

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT produto, pais, SUM(quantidade) AS total_vendas
   FROM pedidos
   WHERE time >= now() - INTERVAL '30 minutes'
   GROUP BY produto, pais
   ORDER BY total_vendas DESC"

```

---

#### Exemplo 12 — Janelas de tempo de 10 segundos

A função `date_bin` divide o eixo do tempo em janelas de tamanho fixo — equivalente ao `aggregateWindow` do Flux.

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT
     date_bin(INTERVAL '10 seconds', time) AS janela,
     produto,
     SUM(quantidade) AS total_vendas
   FROM pedidos
   WHERE time >= now() - INTERVAL '30 minutes'
   GROUP BY janela, produto
   ORDER BY janela"

```

---

#### Exemplo 13 — Vendas do Brasil

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT produto, SUM(quantidade) AS total_vendas
   FROM pedidos
   WHERE time >= now() - INTERVAL '30 minutes'
     AND pais = 'BR'
   GROUP BY produto
   ORDER BY total_vendas DESC"

```

---

#### Exemplo 14 — Vendas de geladeira na Austrália

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT time, quantidade, preco
   FROM pedidos
   WHERE produto = 'GELADEIRA'
     AND pais = 'AU'
     AND time >= now() - INTERVAL '30 minutes'
   ORDER BY time DESC"

```

---

## HTTP API
<br>

O InfluxDB 3 mantém compatibilidade com a API de escrita do InfluxDB 2 (`/api/v2/write`) e adiciona o endpoint SQL (`/api/v3/query_sql`).

### Escrita

```bash
curl -XPOST "http://$(hostname):8086/api/v2/write?bucket=ecommerce&precision=s" \
  --header "Content-Type: text/plain; charset=utf-8" \
  --data-raw 'pedidos,produto=SANDUICHEIRA,pais=BR quantidade=1,preco=200'
```

### Consulta SQL via HTTP

```bash
curl -G "http://$(hostname):8086/api/v3/query_sql" \
  --data-urlencode "db=ecommerce" \
  --data-urlencode "q=SELECT * FROM pedidos ORDER BY time DESC LIMIT 10"
```

Ou via POST com JSON:

```bash
curl -XPOST "http://$(hostname):8086/api/v3/query_sql" \
  --header "Content-Type: application/json" \
  --data '{"db": "ecommerce", "q": "SELECT produto, SUM(quantidade) AS total FROM pedidos GROUP BY produto"}'
```

---

## InfluxDB UI
<br>
O InfluxDB 3 disponibiliza uma interface web de exploração de dados.

### Acessando a InfluxDB UI

- Abra o navegador e acesse `localhost:8086` (ou o endereço do ambiente Cloud9).
- A interface não exige login (laboratório sem autenticação).

### Data Explorer

- No menu lateral, acesse **Data Explorer**.
- Selecione o database `ecommerce`.
- Use o editor SQL para executar consultas diretamente na interface:

```sql
SELECT *
FROM pedidos
WHERE time >= now() - INTERVAL '5 minutes'
ORDER BY time DESC
```

```sql
SELECT produto, SUM(quantidade) AS total_vendas
FROM pedidos
WHERE time >= now() - INTERVAL '30 minutes'
GROUP BY produto
ORDER BY total_vendas DESC
```

---

## Bônus: Grafana

O Grafana é uma plataforma open source de visualização amplamente usada para criar dashboards. Ele já está disponível como parte do ambiente deste laboratório.

### Acessando o Grafana

- Abra o navegador e acesse `localhost:3000` (ou substitua `localhost` pelo endereço do ambiente Cloud9).
- Usuário: `admin` | Senha: `admin`.

### Configurando o InfluxDB 3 como fonte de dados

1. No menu lateral, vá em **Connections > Data Sources > Add data source**.
2. Escolha **InfluxDB**.
3. Preencha os campos:
   - **Query Language**: `SQL`
   - **URL**: `http://influxdb-demo:8086`
   - **Database**: `ecommerce`
4. Clique em **Save & Test**.

### Criando um painel simples

1. Clique em **+** no menu lateral > **New Dashboard > Add visualization**.
2. Selecione o data source **InfluxDB** recém-criado.
3. No editor de query, insira:

```sql
SELECT
  date_bin(INTERVAL '10 seconds', time) AS time,
  produto,
  SUM(quantidade) AS total_vendas
FROM pedidos
WHERE time >= $__timeFrom AND time <= $__timeTo
GROUP BY time, produto
ORDER BY time
```

4. Clique em **Run Query** para visualizar o gráfico de vendas por produto em tempo real.

---

## Parabéns!

Parabéns por concluir o laboratório de Armazenamento de Séries Temporais com InfluxDB 3! Você aprendeu como utilizar o InfluxDB 3 para armazenar e consultar dados de séries temporais usando SQL padrão. Continue praticando e explorando as funcionalidades do InfluxDB para aprimorar ainda mais seus conhecimentos.

Se tiver dúvidas ou sugestões, sinta-se à vontade para entrar em contato.

Bom trabalho e até a próxima!

Prof. Barbosa
