#!/bin/bash

# Функция для отображения меню
show_menu() {
    echo "Выберите скрипт для выполнения:"
    echo "1) Проверить 0gstatus_ip_v02"
    echo "2) Проверить 4hour_0g"
    echo "3) Проверить analyz_0g"
    echo "4) Выйти"
}

# Функция для выполнения выбранного скрипта
execute_script() {
    case $1 in
        1)
            echo "Выполняется Проверка айпи их тотал тайм..."
            # Проверяем существование файла ip_time_log.txt
            if [[ -f ./ip_time_log.txt ]]; then
                echo "Обработка файла ip_time_log.txt..."
                awk '{print "IP:", $1, "- Общее время подключения:", $2, "секунд"}' ./ip_time_log.txt
            else
                echo "Файл ip_time_log.txt не найден. Убедитесь, что файл находится в текущей директории: $(pwd)"
            fi
            ;;
        2)
            echo "Выполняется Проверка ссерверов за последние 4 часа..."
            bash <(curl -s https://raw.githubusercontent.com/YAbl0K0/nodes/master/status/4hour_0g.sh)
            ;;
        3)
            echo "Выполняется Анализ подключения..."
            bash <(curl -s https://raw.githubusercontent.com/YAbl0K0/nodes/master/status/analyz_0g.sh)
            ;;
        4)
            echo "Выход из программы."
            exit 0
            ;;
        *)
            echo "Неверный выбор. Пожалуйста, попробуйте снова."
            ;;
    esac
}

# Основной цикл меню
while true; do
    show_menu
    read -p "Введите номер вашего выбора: " choice
    execute_script "$choice"
    echo ""
done
