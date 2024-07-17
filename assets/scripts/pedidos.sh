#!/usr/bin/env bash
produtos=("TV" "GELADEIRA" "TV" "HOMETHEATER" "COMPUTADOR" "MONITOR" "TABLET" "SOUNDBAR" "CELULAR" "NOTEBOOK")
while(true)
do
    if [ $(expr $i % 2 ) != "0" ]; then
        curl --request POST \
            "http://localhost:8086/api/v2/write?org=infobarbosa&bucket=default&precision=ns" \
            --header "Authorization: Token 3y1c3NnlmA1kA061YlROSO0gE5a1ppH_1Ig5HSMCsCX3VKF6zkrBwAtC-Hr6c_TTU8B9kwYOPphDq6hwyw5tLw==" \
            --header "Content-Type: text/plain; charset=utf-8" \
            --header "Accept: application/json" \
            --data-binary 'pedidos,produto=${produtos[${RANDOM:0:1}]},pais=BR quantidade=${RANDOM:0:2}'

    
    else
        curl --request POST \
            "http://localhost:8086/api/v2/write?org=infobarbosa&bucket=default&precision=ns" \
            --header "Authorization: Token 3y1c3NnlmA1kA061YlROSO0gE5a1ppH_1Ig5HSMCsCX3VKF6zkrBwAtC-Hr6c_TTU8B9kwYOPphDq6hwyw5tLw==" \
            --header "Content-Type: text/plain; charset=utf-8" \
            --header "Accept: application/json" \
            --data-binary 'pedidos,produto=${produtos[${RANDOM:0:1}]},pais=US quantidade=${RANDOM:0:2}'
    fi
    sleep 0.05
done
