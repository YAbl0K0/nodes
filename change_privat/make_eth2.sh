#!/bin/bash

# Вводим путь к файлу Tendermint Private Key
read -p "Введите путь к файлу Tendermint Private Key: " FILE_PATH

# Проверяем существование файла
if [ ! -f "$FILE_PATH" ]; then
  echo "Ошибка: файл не найден!"
  exit 1
fi

# Извлекаем строку Base64 из файла
BASE64_KEY=$(grep -vE 'BEGIN|END|type|kdf|salt' "$FILE_PATH" | tr -d '\n')

# Проверяем, есть ли Base64-строка
if [ -z "$BASE64_KEY" ]; then
  echo "Ошибка: Base64-ключ не найден в файле."
  exit 1
fi

# Декодируем Base64
HEX_KEY=$(echo "$BASE64_KEY" | base64 -d | xxd -p 2>/dev/null)

if [ $? -ne 0 ]; then
  echo "Ошибка: некорректный формат Base64."
  exit 1
fi

echo "Декодированный ключ в формате hex (возможно, зашифрован): $HEX_KEY"

# Проверяем, если ключ зашифрован bcrypt
if grep -q 'kdf: bcrypt' "$FILE_PATH"; then
  echo "Ключ зашифрован bcrypt, требуется пароль для расшифровки."
  read -s -p "Введите пароль для расшифровки: " PASSWORD
  echo ""

  # Извлекаем salt
  SALT=$(grep 'salt:' "$FILE_PATH" | awk '{print $2}' | xxd -r -p | base64 -w 0)

  # Запускаем Python для расшифровки
  DECRYPTED_KEY=$(python3 - <<EOF
import bcrypt, base64, sys

# Вводные данные
salt = base64.b64decode("$SALT")
encrypted_key = base64.b64decode("$BASE64_KEY")
password = b"$PASSWORD"

# Расшифровка
try:
    key = bcrypt.kdf(password=password, salt=salt, desired_key_bytes=32, rounds=12)
    print(key.hex())
except Exception as e:
    print(f"Ошибка: {e}", file=sys.stderr)
    sys.exit(1)
EOF
)

  if [ $? -ne 0 ]; then
    echo "Ошибка: неверный пароль или расшифровка невозможна."
    exit 1
  fi

  echo "Расшифрованный приватный ключ в формате hex: $DECRYPTED_KEY"
else
  echo "Ключ не зашифрован bcrypt. Используйте декодированный hex-ключ."
fi
