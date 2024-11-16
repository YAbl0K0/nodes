#!/bin/bash

while true; do
  # Выполняем запрос и сохраняем вывод
  OUTPUT=$(curl -X POST http://127.0.0.1:4321/api/jobs \
    -H "Content-Type: application/json" \
    -d '{"containers": ["hello-world"], "data": {"some": "input"}}' | jq)

  # Извлекаем значение "id", если оно есть
  ID=$(echo "$OUTPUT" | jq -r '.id // empty')

  # Если значение "id" найдено, запускаем второй цикл
  if [[ -n "$ID" ]]; then
    echo "ID найден: $ID"
    while true; do
      # Отправляем GET-запрос с найденным ID
      GET_OUTPUT=$(curl -X GET "http://127.0.0.1:4321/api/jobs?id=${ID}" | jq)

      # Проверяем, содержит ли ответ "status": "success"
      STATUS=$(echo "$GET_OUTPUT" | jq -r '.[].status // empty')
      if [[ "$STATUS" == "success" ]]; then
        echo "Успех: статус success!"
        echo "$GET_OUTPUT"
        break 2 # Выходим из обоих циклов
      fi

      # Ждем 5 секунд перед повтором
      sleep 5
    done
  fi

  # Ждем 5 секунд перед повтором POST-запроса
  sleep 5
done
