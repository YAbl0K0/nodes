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
            echo "Выполняется Проверка айпи..."
            bash <(curl -s https://raw.githubusercontent.com/YAbl0K0/nodes/refs/heads/master/0G/check_og.sh)
            ;;
        2)
            echo "Выполняется Анализ подключения за 2 часа..."
            bash <(curl -s https://raw.githubusercontent.com/YAbl0K0/nodes/master/status/4hour_0g.sh)
            ;;
        3)
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
