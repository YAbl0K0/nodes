#!/bin/bash

# Запрос приватного ключа от пользователя
read -p "Введите ваш приватный ключ secp256k1 (без пробелов): " TENDERMINT_PRIVATE_KEY

# Проверяем, установлен ли Python
if ! command -v python3 &> /dev/null
then
    echo "Python не установлен. Установите Python 3 для запуска этого скрипта."
    exit 1
fi

# Запускаем Python-скрипт для конвертации
python3 <<EOF
from eth_keys import keys

# Приватный ключ от пользователя
TENDERMINT_PRIVATE_KEY = "$TENDERMINT_PRIVATE_KEY"

try:
    # Преобразуем ключ из hex в байты
    private_key_bytes = bytes.fromhex(TENDERMINT_PRIVATE_KEY)

    # Создаем Ethereum-совместимый приватный ключ
    eth_private_key = keys.PrivateKey(private_key_bytes)

    # Печатаем результаты
    print("Ethereum Private Key:", eth_private_key)
    print("Ethereum Address:", eth_private_key.public_key.to_checksum_address())

except ValueError as e:
    print("Ошибка: Приватный ключ должен быть в формате hex (16-ричный).")
    print("Детали ошибки:", e)
EOF
