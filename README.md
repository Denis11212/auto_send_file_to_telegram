# Установка
Для устновки достаточно скачать [https://github.com/Denis11212/auto_send_file_to_telegram/raw/refs/heads/main/install_auto_send_file_to_telegram.sh](install_auto_send_file_to_telegram.sh), затем дать права файлу на запуск, ну и выполнить скрипт устновки. Устновочный скрипт сам всё сделает. Если нужно будет поменять данные телеграмм бота, то тоже достаточно всего-то опять запустить устновочный скрипт, либо воспользоваться командами UCI:
`uci set auto_send_file_to_telegram.bot_auth.bot_token=bot_token
uci set auto_send_file_to_telegram.bot_auth.chat_id=chat_id`
так как скрипт хранит данные в стандартных для OpenWrt конфигурационном файле `/etc/config/auto_send_file_to_telegram`
