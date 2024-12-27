#!/bin/bash

read -rp "Введите ПРИВАТНЫЙ ключ: " private_key
read -rp "Введите АДРЕС: " wallet_address

tmux kill-session -t shardeum_staking 2>/dev/null
import os
import sys
from random import randint, uniform
from subprocess import CalledProcessError, check_output, Popen
from time import sleep


def start_node():
    start_node_command = [
        'docker', 'exec', '-i', 'shardeum-validator',
        'operator-cli', 'start'
    ]

    return Popen(start_node_command)


def get_stake_amount(wallet_address):
    stake_info_command = [
        'docker', 'exec', '-i', 'shardeum-validator',
        'operator-cli', 'stake_info', wallet_address,
    ]

    try:
        output = check_output(stake_info_command, universal_newlines=True)
        lines = output.split('\n')
        for line in lines:
            if line.startswith('stake:'):
                parts = line.split()
                if len(parts) > 1:
                    return parts[1].strip(\"'\")
    except CalledProcessError as e:
        print(e)
        sys.exit(1)

    return None


def run_stake_command(private_key, stake_value):
    stake_command = [
        'docker', 'exec', '-i', 'shardeum-validator', 'sh', '-c',
        '(sleep 10; echo \"{0}\"; sleep 10) | operator-cli stake {1}'.format(private_key, stake_value),
    ]

    return Popen(stake_command)


def attempt_stake(private_key, wallet_address, num_retries, init_stake_amount):
    for i in range(num_retries):
        try:
            stake_amount = get_stake_amount(wallet_address)
            stake_value = round(uniform(10, 12), 1)

            if stake_amount != init_stake_amount:
                print(f'\033[1;31;40mГОТОВО! Было стейкнуто: {stake_value}\033[m')
                return True

            print(f'ПОПЫТКА СТЕЙКА #{i}')
            stake_process = run_stake_command(private_key, stake_value)
            sleep(randint(40, 90))

            if stake_process.poll() is None:
                stake_process.terminate()
        except CalledProcessError as e:
            print(f'An error from attempt_stake: {e}')

    return False


def main():
    if os.path.exists('credentials.txt'):
        os.remove('credentials.txt')

    start_node()
    private_key = sys.argv[1]
    wallet_address = sys.argv[2]
    init_stake_amount = get_stake_amount(wallet_address)
    is_staked = (
            attempt_stake(private_key, wallet_address, 3, init_stake_amount) or
            sleep(randint(1000, 2000)) or
            attempt_stake(private_key, wallet_address, randint(5, 6), init_stake_amount)
    )

    print(f'is_staked: {is_staked}')


main()" $private_key $wallet_address

echo -e "\033[1;31;40mЧЕРЕЗ ЧАС ВАМ НУЖНО ПРОВЕРИТЬ ЗАСТЕЙКАНЫЕ ТОКЕНЫ В ЕКСПЛОРЕРЕ. ЕСЛИ ТОКЕНОВ НЕ БУДЕТ, ТО ЗАПУСКАЕМ СКРИПТ ЕЩЕ РАЗ\033[m"
