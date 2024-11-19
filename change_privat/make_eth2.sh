#!/bin/bash

# Вводим Base64-строку из TENDERMINT PRIVATE KEY
read -p "Введите Base64-строку из TENDERMINT PRIVATE KEY: " BASE64_KEY

# Декодируем Base64 в Hex
HEX_KEY=$(echo "$BASE64_KEY" | base64 -d | xxd -p 2>/dev/null)

# Проверяем, успешно ли декодировалось
if [ $? -ne 0 ]; then
  echo "Ошибка: некорректный формат Base64."
  exit 1
fi

echo "Декодированный ключ в формате hex: $HEX_KEY"

