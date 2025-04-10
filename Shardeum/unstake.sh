#!/bin/bash

# Проверка, установлен ли tmux
if ! command -v tmux &> /dev/null
then
    echo "tmux не установлен. Установите его с помощью команды: sudo apt install tmux"
    exit 1
fi

# Запрос приватного ключа
read -p "Введите приватный ключ от тестнет кошелька Shardeum: " PRIVATE_KEY
echo ""

# Название tmux-сессии
SESSION_NAME="shardeum_unstake"

# Проверка текущего значения lockedStake
LOCKED_STAKE=$(docker exec -i shardeum-validator operator-cli status | grep "lockedStake:" | awk '{print $2}' | tr -d "'")

if [[ -z "$LOCKED_STAKE" || "$LOCKED_STAKE" == "0.0" ]]; then
    echo "Делаю анстейк с другой ноды"
    LOCKED_STAKE=10
else
    echo "Текущее значение lockedStake: $LOCKED_STAKE"
fi

# Удаление существующей tmux-сессии
if tmux has-session -t $SESSION_NAME 2>/dev/null; then
    tmux kill-session -t $SESSION_NAME
fi

# Запуск tmux-сессии
tmux new-session -d -s $SESSION_NAME

# Выполнение команд в tmux
tmux send-keys -t $SESSION_NAME "cd ~/shardeum && ./shell.sh" C-m
tmux send-keys -t $SESSION_NAME "operator-cli stop" C-m
tmux send-keys -t $SESSION_NAME "echo \"$PRIVATE_KEY\" | operator-cli unstake $LOCKED_STAKE" C-m
tmux send-keys -t $SESSION_NAME "sleep 60" C-m
tmux send-keys -t $SESSION_NAME "exit" C-m

# Подымаем ноду
docker exec -i shardeum-validator operator-cli start

# Информация о процессе
echo "Вы можете проверить статус в любой момент командой: tmux attach -t $SESSION_NAME"
echo "Анстейк выполнится через 1 минуту"
