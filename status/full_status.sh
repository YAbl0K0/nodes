#!/bin/bash

# Автоматическое создание имени файла отчета с текущей датой и временем
REPORT_FILENAME="combined_report_$(date '+%Y-%m-%d_%H-%M-%S').txt"
REPORT_FILE="./$REPORT_FILENAME"

# Параметры для Docker-контейнеров
NECESSARY_CONTAINERS=("elixir" "ipfs_node" "orchestrator" "shardeum-dashboard" "updater" "mongodb" "docker-watchtower-1")
UNNECESSARY_CONTAINERS=("subspace_docker-node-1" "allora-worker" "boolnetwork" "subspace_docker-farmer-1" "kroma-validator" "kroma-node" "kroma-geth" "run_nillion" "allora-worker" "source-02" "source-03" "source-01" "bevm-node")

# Параметры для файлов и папок
NECESSARY_ITEMS=("0g_backup" "0g-chain" "0g-storage-client" ".bashrc" ".sonaric" "0g-storage-node" ".nesa" "multipleforlinux" "multiple-node" "3proxy-0.9.3" "foundry" "all-in-one-v2" "allora-chain" "btop.tbz" "data" "elixir" "go" "heminetwork" "infernet-container-starter" "installer.sh" "install_zabbix.sh" "sentry-node-cli-linux" "star_labs" "start.sh" "update.txt" "vmagent-prod" "vmalert-prod" "vmauth-prod" "vmbackup-prod" "vmctl-prod" "vmrestore-prod" "zabbix-release_6.4-1+ubuntu22.04_all.deb" ".0gchain" ".config" ".profile" ".docker")
UNNECESSARY_ITEMS=("0gchain_snapshot.lz4" "0gchain_snapshot.lz4.aria2" "rusk" "namada" "masa-oracle-go-testnet" "light_0gchain_snapshot.lz4" ".masa" "0.9.3.tar.gz" "0.9.3.tar.gz.1" "BeraMachine" "dusk_global_height.json" "gear" "basic-coin-prediction-node" "bevm" "allora-worker-x-reputer" "allora-huggingface-walkthrough" "nillion" "gear_key" "masa-oracle-go-testnet" "subspace_docker" "my-cryptopunks-squid" "sentry-node-cli-linux.zip" "storage_0gchain_snapshot.lz4" "uniform-load-squid" "zabbix-release_6.4-1+ubuntu22.04_all.deb.1" "zabbix-release_6.4-1+ubuntu22.04_all.deb.2" "zabbix-release_6.4-1+ubuntu22.04_all.deb.3" "zabbix-release_6.4-1+ubuntu22.04_all.deb.4" "my-single-proc-squid" "my-double-proc-squid" "my-triple-proc-squid" "my-quad-proc-squid" "my-snapshot-squid" "fractal-node" ".bitcoin")

# Сбор всех контейнеров с их статусами и временем создания
ALL_CONTAINERS=$(docker ps -a --format '{{.Names}};{{.Status}};{{.CreatedAt}}')

# Сбор файлов и папок в текущей директории
ITEMS=$(ls)

# Массивы для классификации Docker-контейнеров
DOCKER_TO_KEEP=()     # Запущенные и необходимые контейнеры
DOCKER_TO_REMOVE=()   # Контейнеры на удаление
DOCKER_UNKNOWN=()     # Неизвестные контейнеры

# Массивы для классификации файлов и папок
FILES_TO_KEEP=()      # Необходимые файлы и папки
FILES_TO_REMOVE=()    # Файлы и папки на удаление
FILES_UNKNOWN=()      # Неизвестные файлы и папки

# Функция для анализа Docker-контейнеров
analyze_containers() {
  while IFS=';' read -r name status created_at; do
    container_info="$name (Статус: $status, Создан: $created_at)"

    if [[ " ${NECESSARY_CONTAINERS[@]} " =~ " $name " ]]; then
      DOCKER_TO_KEEP+=("$container_info")
    elif [[ " ${UNNECESSARY_CONTAINERS[@]} " =~ " $name " ]]; then
      DOCKER_TO_REMOVE+=("$container_info")
    else
      DOCKER_UNKNOWN+=("$container_info")
    fi
  done <<< "$ALL_CONTAINERS"
}

# Функция для анализа файлов и папок
analyze_items() {
  for item in $ITEMS; do
    if [[ " ${NECESSARY_ITEMS[@]} " =~ " $item " ]]; then
      FILES_TO_KEEP+=("$item")
    elif [[ " ${UNNECESSARY_ITEMS[@]} " =~ " $item " ]]; then
      FILES_TO_REMOVE+=("$item")
    else
      FILES_UNKNOWN+=("$item")
    fi
  done
}

# Анализируем контейнеры и файлы
analyze_containers
analyze_items

# Запись отчета в файл в одну строку в нужном порядке
{
  echo "$(date '+%Y-%m-%d'); FILES_TO_KEEP: $(IFS=','; echo "${FILES_TO_KEEP[*]}"), FILES_TO_REMOVE: $(IFS=','; echo "${FILES_TO_REMOVE[*]}"), FILES_UNKNOWN: $(IFS=','; echo "${FILES_UNKNOWN[*]}"), DOCKER_TO_KEEP: $(IFS=','; echo "${DOCKER_TO_KEEP[*]}"), DOCKER_TO_REMOVE: $(IFS=','; echo "${DOCKER_TO_REMOVE[*]}"), DOCKER_UNKNOWN: $(IFS=','; echo "${DOCKER_UNKNOWN[*]}")"
} > "$REPORT_FILE"

# Сообщение об успешной записи отчета
echo "Отчет сохранен в $REPORT_FILE"
