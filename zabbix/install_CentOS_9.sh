#!/usr/bin/env bash
set -euo pipefail

hostname="${HOST_NAME:-}"
server_ip="65.108.196.236"
LOGFILE="/var/log/zabbix_install.log"

if [[ -z "$hostname" ]]; then
  echo "Замена HOST_NAME" | tee -a "$LOGFILE"
  exit 1
fi

run_command() {
  echo "Использую: sudo $*" | tee -a "$LOGFILE"
  if sudo "$@"; then
    echo "OK: $*" | tee -a "$LOGFILE"
  else
    status=$?
    echo "Ошибка: $* (код $status)" | tee -a "$LOGFILE"
    return $status
  fi
}

remove_old_zabbix() {
  echo "=== Удаление старого Zabbix агентa ===" | tee -a "$LOGFILE"

  if systemctl list-units --full -all | grep -q "zabbix-agent"; then
    run_command systemctl stop zabbix-agent || true
  fi
  if systemctl list-units --full -all | grep -q "zabbix-agent2"; then
    run_command systemctl stop zabbix-agent2 || true
  fi

  # Видаляємо пакети з dnf (EL9)
  run_command dnf remove -y zabbix-agent zabbix-agent2 || true
  # (опційно) прибрати репопакет, якщо був
  run_command dnf remove -y zabbix-release || true

  # Конфіги
  if [[ -d "/etc/zabbix" ]]; then
    run_command rm -rf /etc/zabbix
  fi

  echo "=== Старый агент Zabbix удалено ===" | tee -a "$LOGFILE"
}

install_zabbix() {
  echo "=== Установка Zabbix агентa (EL9) ===" | tee -a "$LOGFILE"

  # Визначаємо архітектуру для правильного URL репо
  arch="$(uname -m)"
  case "$arch" in
    x86_64|aarch64) ;;
    *)
      echo "Неверная архетектура: $arch" | tee -a "$LOGFILE"
      exit 1
      ;;
  esac

  # Офіційний репозиторій Zabbix 6.4 для RHEL/CentOS 9
  # Якщо версія релізного rpm зміниться — dnf встановить по прямому URL без dpkg/apt.
  zbx_repo_url="https://repo.zabbix.com/zabbix/6.4/rhel/9/${arch}/zabbix-release-6.4-1.el9.noarch.rpm"

  # Встановлюємо репозиторій і агент
  run_command dnf install -y "$zbx_repo_url"
  run_command dnf clean all
  run_command dnf makecache
  run_command dnf install -y zabbix-agent

  # Увімкнути автозапуск
  run_command systemctl enable zabbix-agent
  run_command systemctl restart zabbix-agent

  echo "=== Zabbix агент установлено ===" | tee -a "$LOGFILE"
}

config_zabbix() {
  echo "=== Налаштування Zabbix агентa ===" | tee -a "$LOGFILE"

  # Переконуємось, що конфіг існує
  if [[ ! -f /etc/zabbix/zabbix_agentd.conf ]]; then
    echo "Конфиг /etc/zabbix/zabbix_agentd.conf не найдено." | tee -a "$LOGFILE"
    exit 1
  fi

  run_command sed -i "s/^Hostname=.*/Hostname=${hostname}/" /etc/zabbix/zabbix_agentd.conf
  run_command sed -i "s/^Server=.*/Server=${server_ip}/" /etc/zabbix/zabbix_agentd.conf
  run_command sed -i "s/^ServerActive=.*/ServerActive=${server_ip}/" /etc/zabbix/zabbix_agentd.conf
  # Увімкнути HostMetadata для авто-реєстрації, якщо було закоментовано
  if grep -qE '^\s*#\s*HostMetadata=' /etc/zabbix/zabbix_agentd.conf; then
    run_command sed -i "s/^\s*#\s*HostMetadata=.*/HostMetadata=autoreg.linux/" /etc/zabbix/zabbix_agentd.conf
  else
    # Якщо рядок відсутній — додамо
    if ! grep -q '^HostMetadata=' /etc/zabbix/zabbix_agentd.conf; then
      echo "HostMetadata=autoreg.linux" | sudo tee -a /etc/zabbix/zabbix_agentd.conf >/dev/null
    else
      run_command sed -i "s/^HostMetadata=.*/HostMetadata=autoreg.linux/" /etc/zabbix/zabbix_agentd.conf
    fi
  fi

  run_command systemctl restart zabbix-agent
  run_command systemctl status --no-pager zabbix-agent || true

  echo "=== Настройку завершено ===" | tee -a "$LOGFILE"
}

echo "=== Старт скрипта (CentOS Stream 9) ===" | tee -a "$LOGFILE"
remove_old_zabbix
install_zabbix
config_zabbix
echo "=== ГОТОВО!!! ===" | tee -a "$LOGFILE"
