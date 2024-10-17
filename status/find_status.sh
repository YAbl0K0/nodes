#!/bin/bash

# Запрос имени файла у пользователя
read -p "Введите имя файла для отчета (пример: report.txt): " REPORT_FILENAME

# Проверка, что имя файла не пустое
if [ -z "$REPORT_FILENAME" ]; then
  echo "Ошибка: Имя файла не может быть пустым."
  exit 1
fi

# Параметры
NECESSARY_ITEMS=("0.9.3.tar.gz" "BeraMachine" "hubble" "star_labs" "zabbix-release_6.4-1+ubuntu20.04_all.deb.1")
UNNECESSARY_ITEMS=("0.9.3.tar.gz.1" "bevm" "infernet-container-starter" "start.sh" "zabbix-release_6.4-1+ubuntu20.04_all.deb.10")
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
