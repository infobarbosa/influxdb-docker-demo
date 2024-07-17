# Armazenamento de Séries Temporais com InfluxDB

Author: Prof. Barbosa<br>
Contact: infobarbosa@gmail.com<br>
Github: [infobarbosa](https://github.com/infobarbosa)

O objetivo desse laboratório é oferecer ao aluno ambiente onde de familiarização com o modelo de armazenamento de séries temporais utilizando **InfluxDB**.

## InfluxDB

[InfluxDB](https://docs.influxdata.com/influxdb/v2/get-started/) é um banco de dados de série temporal de código aberto desenvolvido pela empresa InfluxData. Ele é usado para armazenamento e recuperação de dados de séries temporais em áreas como monitoramento de operações, métricas de aplicativos, dados de sensores da Internet das Coisas e análises em tempo real.<br>
> Fonte: [Wikipedia](https://en.wikipedia.org/wiki/InfluxDB)

## Line Protocol
<br>
O protocolo de linha (line protocol) do InfluxDB é um formato simples baseado em texto adotado para escrita de data points no banco de dados.
<br>

#### Sintaxe

```
<measurement>[,<tag_key>=<tag_value>[,<tag_key>=<tag_value>]] <field_key>=<field_value>[,<field_key>=<field_value>] [<timestamp>]
``` 
Onde:
- `<measurement>` (obrigatório e case-sensitive) <br>
Tipo `string` que representa o nome da medida. 

- `<tag_key>=<tag_value>` (não obrigatório, porém case-sensitive) <br>
Tags representadas por pares chave-valor para o data point.<br> 
A relação entre chave e valor é representada pelo operador `=`.<br> 
Ambos chave e valor devem ser do tipo `string`.<br>
O protocolo suporta múltiplas ocorrências de tags.

- `<field_key>=<field_value>` (obrigatório e case-sensitive)
Fields (campos) representadas por pares chave-valor para o data point.<br>
Points necessitam ter pelo menos um Field.<br>
Fields keys (chaves) devem ser do tipo `string`, field values (valores) podem ser dos tipos `Float`, `Integer`, `UInteger`, `String` e `Boolean`.

- `[<timestamp>]` é expresso em nanossegundos e não obrigatório.<br>
**Atenção!** Caso não informado no protocolo de linha, o InfluxDB atribuirá um valor baseado no  timestamp interno do servidor.

**Exemplo**:
```
pedidos,produto=GELADEIRA Quantity=1,UnitPrice=2000 1668387574000000000
```
