#!/bin/bash

clear
# Актуально на 19.10.2024

# Автоматическое создание имени файла отчета с текущей датой и временем
REPORT_FILENAME="docker_report_$(date '+%Y-%m-%d_%H-%M-%S').txt"
REPORT_FILE="./$REPORT_FILENAME"

# Параметры для Docker-контейнеров
NECESSARY_CONTAINERS=("elixir" "ipfs_node" "orchestrator" "run_nillion" "shardeum-dashboard" "allora-worker" "source-02" "source-03" "source-01" "updater" "mongodb" "docker-watchtower-1" "bevm-node")
UNNECESSARY_CONTAINERS=("subspace_docker-node-1" "subspace_docker-farmer-1" "kroma-validator" "kroma-node" "kroma-geth")

# Параметры для файлов и папок
NECESSARY_ITEMS=("0g_backup" "0g-chain" "0g-storage-client" "0g-storage-node" "3proxy-0.9.3" "all-in-one-v2" "allora-chain" "allora-huggingface-walkthrough" "allora-worker-x-reputer" "basic-coin-prediction-node" "bevm" "btop.tbz" "data" "elixir" "go" "heminetwork" "infernet-container-starter" "installer.sh" "install_zabbix.sh" "nillion" "sentry-node-cli-linux" "star_labs" "start.sh" "subspace_docker" "update.txt" "vmagent-prod" "vmalert-prod" "vmauth-prod" "vmbackup-prod" "vmctl-prod" "vmrestore-prod" "zabbix-release_6.4-1+ubuntu22.04_all.deb" ".0gchain" ".config" ".profile" ".docker")
UNNECESSARY_ITEMS=("0gchain_snapshot.lz4" "0gchain_snapshot.lz4.aria2" "0.9.3.tar.gz" "0.9.3.tar.gz.1" "BeraMachine" "dusk_global_height.json" "gear" "gear_key" "masa-oracle-go-testnet" "my-cryptopunks-squid" "sentry-node-cli-linux.zip" "storage_0gchain_snapshot.lz4" "uniform-load-squid" "zabbix-release_6.4-1+ubuntu22.04_all.deb.1" "zabbix-release_6.4-1+ubuntu22.04_all.deb.2" "zabbix-release_6.4-1+ubuntu22.04_all.deb.3" "zabbix-release_6.4-1+ubuntu22.04_all.deb.4" "my-single-proc-squid" "my-double-proc-squid" "my-triple-proc-squid" "my-quad-proc-squid" "my-snapshot-squid" "fractal-node" ".bitcoin")

# Сбор всех контейнеров с их статусами и временем создания
ALL_CONTAINERS=$(docker ps -a --format '{{.Names}};{{.Status}};{{.CreatedAt}}')

# Сбор файлов и папок в текущей директории
ITEMS=$(ls)

# Массивы для классификации Docker-контейнеров
DOCKER_TO_KEEP=()
DOCKER_TO_REMOVE=()
DOCKER_UNKNOWN=()

# Массивы для классификации файлов и папок
FILES_TO_KEEP=()
FILES_TO_REMOVE=()
FILES_UNKNOWN=()

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

# Выполнение анализа
analyze_containers
analyze_items

# Запись отчета в файл в одну строку
{
  echo "$(date '+%Y-%m-%d'); $(IFS=','; echo "${FILES_TO_KEEP[*]}"); $(IFS=','; echo "${FILES_TO_REMOVE[*]}"); $(IFS=','; echo "${FILES_UNKNOWN[*]}"); $(IFS=','; echo "${DOCKER_TO_KEEP[*]}"); $(IFS=','; echo "${DOCKER_TO_REMOVE[*]}"); $(IFS=','; echo "${DOCKER_UNKNOWN[*]}")"
} > "$REPORT_FILE"

# Вывод содержимого отчета в консоль
cat "$REPORT_FILE"

# Ожидание 180 секунд перед очисткой экрана и удалением файла
sleep 180

# Очистка экрана
clear

# Удаление отчета с правами sudo
sudo rm "$REPORT_FILE"
