#!/bin/bash

# Запрос имени файла у пользователя
read -p "Введите имя файла для отчета (пример: report.txt): " REPORT_FILENAME

# Проверка, что имя файла не пустое
if [ -z "$REPORT_FILENAME" ]; then
  echo "Ошибка: Имя файла не может быть пустым."
  exit 1
fi

# Параметры
NECESSARY_ITEMS=("0g_backup" "0g-chain" "0g-storage-client" "0g-storage-node" "3proxy-0.9.3" "all-in-one-v2" "allora-chain" "allora-huggingface-walkthrough" "allora-worker-x-reputer" "basic-coin-prediction-node" "bevm" "btop.tbz" "data" "elixir" "go" "heminetwork" "infernet-container-starter" "installer.sh" "install_zabbix.sh" "nillion" "sentry-node-cli-linux" "star_labs" "start.sh" "subspace_docker" "update.txt" "vmagent-prod" "vmalert-prod" "vmauth-prod" "vmbackup-prod" "vmctl-prod" "vmrestore-prod" "zabbix-release_6.4-1+ubuntu22.04_all.deb" ".0gchain" ".0gchain" ".config" ".profile" ".docker")
UNNECESSARY_ITEMS=("0gchain_snapshot.lz4" "0gchain_snapshot.lz4.aria2" "0.9.3.tar.gz" "0.9.3.tar.gz.1" "BeraMachine" "dusk_global_height.json" "gear" "gear_key" "masa-oracle-go-testnet" "my-cryptopunks-squid" "sentry-node-cli-linux.zip" "storage_0gchain_snapshot.lz4" "uniform-load-squid" "zabbix-release_6.4-1+ubuntu22.04_all.deb.1" "zabbix-release_6.4-1+ubuntu22.04_all.deb.2" "zabbix-release_6.4-1+ubuntu22.04_all.deb.3" "zabbix-release_6.4-1+ubuntu22.04_all.deb.4" "my-single-proc-squid" "my-double-proc-squid" "my-triple-proc-squid" "my-quad-proc-squid" "my-snapshot-squid" "uniform-load-squid" "fractal-node" ".bitcoin" "" "")
REPORT_FILE="./$REPORT_FILENAME"  # Сохраняем отчет в текущей директории

# Сбор всех файлов и папок в текущей директории
ITEMS=$(ls)

# Массивы для классификации элементов
TO_KEEP=()
TO_REMOVE=()
UNKNOWN=()

# Функция для анализа элементов
analyze_items() {
  for item in $ITEMS; do
    if [[ " ${NECESSARY_ITEMS[@]} " =~ " $item " ]]; then
      TO_KEEP+=("$item")
    elif [[ " ${UNNECESSARY_ITEMS[@]} " =~ " $item " ]]; then
      TO_REMOVE+=("$item")
    else
      UNKNOWN+=("$item")
    fi
  done
}

# Анализируем файлы и папки
analyze_items

# Запись отчета в файл
{
  echo "TO_KEEP: $(IFS=';'; echo "${TO_KEEP[*]}")"
  echo "TO_REMOVE: $(IFS=';'; echo "${TO_REMOVE[*]}")"
  echo "UNKNOWN: $(IFS=';'; echo "${UNKNOWN[*]}")"
} > "$REPORT_FILE"

# Сообщение об успешной записи отчета
echo "Отчет сохранен в $REPORT_FILE"
