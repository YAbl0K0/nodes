#!/bin/bash

# Запрос нового значения для rpc_url / RPC_URL
read -p "Введите новую rpc: " new_rpc

# Файлы для изменения
json_files=(
    "$HOME/infernet-container-starter/deploy/config.json"
    "$HOME/infernet-container-starter/projects/hello-world/container/config.json"
)
makefile="$HOME/infernet-container-starter/projects/hello-world/contracts/Makefile"

# Замена rpc_url в JSON-файлах
for file in "${json_files[@]}"; do
    if [[ -f $file ]]; then
        sed -i "s|\"rpc_url\": \".*\"|\"rpc_url\": \"$new_rpc\"|g" "$file"
        echo "Значение rpc_url изменено в файле: $file"
    else
        echo "Файл не найден: $file"
    fi
done

# Замена RPC_URL в Makefile
if [[ -f $makefile ]]; then
    sed -i "s|^RPC_URL :=.*|RPC_URL := $new_rpc|g" "$makefile"
    echo "Значение RPC_URL изменено в файле: $makefile"
else
    echo "Файл не найден: $makefile"
fi

echo "Замена завершена."
docker compose -f $HOME/infernet-container-starter/deploy/docker-compose.yaml restart
