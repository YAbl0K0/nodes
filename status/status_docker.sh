#!/bin/bash

# Автоматическое создание имени файла отчета с текущей датой и временем
REPORT_FILENAME="docker_report_$(date '+%Y-%m-%d_%H-%M-%S').txt"
REPORT_FILE="./$REPORT_FILENAME"

# Параметры: ожидаемые и нежелательные контейнеры
NECESSARY_CONTAINERS=("elixir" "ipfs_node" "orchestrator" "run_nillion" "shardeum-dashboard" "allora-worker" "source-02" "source-03" "source-01" "updater" "mongodb" "docker-watchtower-1" "bevm-node")
UNNECESSARY_CONTAINERS=("subspace_docker-node-1" "subspace_docker-farmer-1" "kroma-validator" "kroma-node" "kroma-geth")

# Сбор всех контейнеров с их статусами и временем создания
ALL_CONTAINERS=$(docker ps -a --format '{{.Names}};{{.Status}};{{.CreatedAt}}')

# Массивы для классификации контейнеров
TO_KEEP=()           # Запущенные и необходимые контейнеры
TO_REMOVE=()         # Контейнеры на удаление (запущенные или остановленные)
UNKNOWN=()           # Неизвестные контейнеры

# Функция для анализа контейнеров
analyze_containers() {
  while IFS=';' read -r name status created_at; do
    container_info="$name (Статус: $status, Создан: $created_at)"

    if [[ " ${NECESSARY_CONTAINERS[@]} " =~ " $name " ]]; then
      if [[ "$status" == Up* ]]; then
        TO_KEEP+=("$container_info")
      else
      echo "///"
      fi
    elif [[ " ${UNNECESSARY_CONTAINERS[@]} " =~ " $name " ]]; then
      TO_REMOVE+=("$container_info")
    else
      UNKNOWN+=("$container_info")
    fi
  done <<< "$ALL_CONTAINERS"
}

# Анализируем контейнеры
analyze_containers

# Запись отчета в файл в одну строку
{
   echo "$(date '+%Y-%m-%d'); $(IFS=','; echo "${FILES_TO_KEEP[*]}"), $(IFS=','; echo "${FILES_TO_REMOVE[*]}"), $(IFS=','; echo "${FILES_UNKNOWN[*]}"), $(IFS=','; echo "${DOCKER_TO_KEEP[*]}"), $(IFS=','; echo "${DOCKER_TO_REMOVE[*]}"), $(IFS=','; echo "${DOCKER_UNKNOWN[*]}")"

# Сообщение об успешной записи отчета
echo "Отчет о Docker-контейнерах сохранен в $REPORT_FILE"
