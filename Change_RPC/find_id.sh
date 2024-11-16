#!/bin/bash

while true; do
  # Выполняем запрос и сохраняем вывод
  OUTPUT=$(curl -X POST http://127.0.0.1:4321/api/jobs \
    -H "Content-Type: application/json" \
    -d '{"containers": ["hello-world"], "data": {"some": "input"}}' | jq)
  
  # Проверяем, содержит ли вывод строку с "id"
  if echo "$OUTPUT" | grep -q '"id"'; then
    echo "Успех: найден id!"
    echo "$OUTPUT"
    break
  fi

  # Ждем 5 секунд перед повтором
  sleep 5
done
