#!/bin/bash

# Вводим приватный ключ в формате hex
read -p "Введите приватный ключ (hex): " PRIVATE_KEY_HEX

# Проверяем длину ключа (должен быть 64 символа)
if [ ${#PRIVATE_KEY_HEX} -ne 64 ]; then
  echo "Ошибка: Приватный ключ должен содержать ровно 64 символа (32 байта)."
  exit 1
fi

# Используем Python для создания Ethereum-ключа
RESULT=$(python3 - <<EOF
from eth_keys import keys

# Hex-ключ
private_key_hex = "$PRIVATE_KEY_HEX"
private_key_bytes = bytes.fromhex(private_key_hex)

# Создаём Ethereum-ключ
eth_private_key = keys.PrivateKey(private_key_bytes)

# Вывод результата
print("Ethereum Private Key:", eth_private_key)
print("Ethereum Address:", eth_private_key.public_key.to_checksum_address())
EOF
)

# Проверяем, успешно ли выполнен скрипт
if [ $? -ne 0 ]; then
  echo "Ошибка: Не удалось создать Ethereum-ключ. Проверьте корректность приватного ключа."
  exit 1
fi

# Выводим результат
echo "$RESULT"
