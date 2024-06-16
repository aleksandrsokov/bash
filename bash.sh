#!/bin/bash

# Функция для проверки наличия блокировки и создания файла блокировки
check_lock() {
    if [[ -f /tmp/analyze_log.lock ]]; then
        echo "Скрипт уже запущен. Пожалуйста, дождитесь его завершения."
        exit 1
    fi
    touch /tmp/analyze_log.lock
}

# Функция для удаления файла блокировки
remove_lock() {
    rm /tmp/analyze_log.lock
}

# Функция для анализа IP адресов с наибольшим количеством запросов
analyze_ip_addresses() {
    awk -v last_run="$LAST_RUN" '$4 > last_run { ips[$1]++ } END { for (ip in ips) print ip, ips[ip] }' "$LOG_FILE" | sort -rnk2 | head -n 10
}

# Функция для анализа URL с наибольшим количеством запросов
analyze_urls() {
    awk -v last_run="$LAST_RUN" '$4 > last_run { urls[$7]++ } END { for (url in urls) print url, urls[url] }' "$LOG_FILE" | sort -rnk2 | head -n 10
}

# Функция для анализа ошибок веб-сервера/приложения
analyze_errors() {
    awk -v last_run="$LAST_RUN" '$4 > last_run && $9 >= 400 { print $9 }' "$LOG_FILE" | sort | uniq -c
}

# Функция для анализа кодов HTTP ответа
analyze_http_codes() {
    awk -v last_run="$LAST_RUN" '$4 > last_run { http_codes[$9]++ } END { for (code in http_codes) print code, http_codes[code] }' "$LOG_FILE"
}

send_email_results() {
    {
        echo "Subject: Результаты анализа лог файла"
        echo
        echo "Обработка лога с $LAST_RUN по $CURRENT_TIME"
        echo
        echo "Список IP адресов (с наибольшим кол-вом запросов):"
        analyze_ip_addresses
        echo
        echo "Список запрашиваемых URL (с наибольшим кол-вом запросов):"
        analyze_urls
        echo
        echo "Ошибки веб-сервера/приложения:"
        analyze_errors
        echo
        echo "Список всех кодов HTTP ответа:"
        analyze_http_codes
    } | mail -s "Результаты анализа лог файла" test@test.com
}

# Основной код скрипта
check_lock

LOG_FILE="/home/alex/access.log"
LAST_RUN_FILE="/var/log/last_Run_Dont_Remuve_ThisFile"

if [[ ! -f "$LAST_RUN_FILE" ]]; then
    touch /var/log/last_Run_Dont_Remuve_ThisFile
    sleep 1m
fi

if [[ ! -f "$LOG_FILE" ]]; then
    echo "Лог файл не найден."
    remove_lock
    exit 1
fi

LAST_RUN=$(date -r /var/log/last_Run_Dont_Remuve_ThisFile)
CURRENT_TIME=$(date)

send_email_results  # Вызов функции для отправки письма

touch /var/log/last_Run_Dont_Remuve_ThisFile
remove_lock