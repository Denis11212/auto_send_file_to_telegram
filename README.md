# Установка
Для устновки достаточно скачать [install_auto_send_file_to_telegram.sh](https://github.com/Denis11212/auto_send_file_to_telegram/raw/refs/heads/main/install_auto_send_file_to_telegram.sh), затем дать права файлу на запуск, ну и выполнить скрипт устновки. Устновочный скрипт сам всё сделает. Если нужно будет поменять данные телеграмм бота, то тоже достаточно всего-то опять запустить устновочный скрипт, либо воспользоваться командами UCI:
```Shell
uci set auto_send_file_to_telegram.bot_auth.bot_token=токен_вашего_бота
uci set auto_send_file_to_telegram.bot_auth.chat_id=ваш_идентификатор_чата
uci set auto_send_file_to_telegram.sub_folder.sub_folder_name_path=папка_с_отслеживамой_ботом_папкой
uci set auto_send_file_to_telegram.sub_folder.sub_folder_name=название_отслеживаемой_ботом_папки
```

Так как скрипт хранит данные в стандартных для OpenWrt конфигурационном файле `/etc/config/auto_send_file_to_telegram`
