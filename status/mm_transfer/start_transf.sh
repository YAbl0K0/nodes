#!/bin/bash

read -p "Введите адрес кошелька получателя (0x...): " RECIPIENT

# Проверяем, что адрес начинается с 0x
if [[ ! $RECIPIENT =~ ^0x[0-9a-fA-F]{40}$ ]]; then
  echo "❌ Ошибка: некорректный адрес. Должен начинаться с 0x и содержать 40 символов."
  exit 1
fi

# Запуск команды
echo "Выполняется перевод на адрес: $RECIPIENT ..."
python3 transfer_0g.py \
  --recipient "$RECIPIENT" \
  --mode all \
  --leave-native 0.01 \
  --mnemonics mnemonics.txt \
  --rpc https://evmrpc.0g.ai \
  --force-any-words
