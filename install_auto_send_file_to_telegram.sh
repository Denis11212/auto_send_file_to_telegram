#!/bin/sh

if [ $(id -u) -ne 0 ]; then
	echo "Скрипт должен запускаться от имени root или другого пользователя с привилегиями суперпользователя. Например, $ sudo "$0""
	exit 1
fi

echo "Происходит загрузка auto_send_file_to_telegram, подождите…"
curl -L -o "/usr/bin/auto_send_file_to_telegram.sh" "https://github.com/Denis11212/auto_send_file_to_telegram/raw/refs/heads/main/auto_send_file_to_telegram.sh"

cat << EOF > /etc/init.d/auto_send_file_to_telegram
#!/bin/sh /etc/rc.common

START=99
STOP=01

start() {
        echo "Запуск auto_send_file_to_telegram"
        /usr/bin/auto_send_file_to_telegram.sh &
}

stop() {
        echo "auto_send_file_to_telegram будет остановлен"
        killall auto_send_file_to_telegram.sh
}
EOF

# Создание UCI-конфигурационного файла (ему нужно потом не забыть дать права, чтобы читать мог только root пользователь).
cat << EOF > /etc/config/auto_send_file_to_telegram
config auto_send_file_to_telegram 'bot_auth'
  option bot_token 'token'
  option chat_id 'idchat'

config auto_send_file_to_telegram 'sub_folder'
  option sub_folder_name_path '/tmp/auto_send_file_to_telegram'
  option sub_folder_name 'new'
EOF

# Командами нужно дать права
chmod +x /usr/bin/auto_send_file_to_telegram.sh
chmod +x /etc/init.d/auto_send_file_to_telegram
chmod 600 /etc/config/auto_send_file_to_telegram

echo "Скрипт использует запись данных в выбранную вами область памяти. Частая перезапись в Flash-память устройства может привести к её износу. Хранение данных в ОЗУ удобно, но ненадёжно из-за потери данных при отключении питания. Можно использовать внешние накопители, такие как MicroSD, NVMe, HDD или USB-флэшки с хорошим ресурсом и/или если вам их не жалко. Ведь если выйдет из строя Nand память на роутере, то её замена относительно сложная и дорогая. В некоторых случаях проще или дешевле будет купить новый роутер."

/etc/init.d/auto_send_file_to_telegram enable # Добавить скрипт в автозагрузку
reboot # Перезапустить устройство
# /etc/init.d/auto_send_file_to_telegram start # не вижу смысла запускать, лучше выполнить reboot перезагрузку

# echo 55 > /tmp/new/1.txt # Записать в файлик, чтобы проверить, что скрипт работает в фоновом режиме. Файлик должен будет автоматически отправиться телеграмм боту

# Пример упрвления через uci, в котором выстявляются нужные параметры
#uci set auto_send_file_to_telegram.bot_auth.bot_token=bottoken
#uci set auto_send_file_to_telegram.bot_auth.chat_id=chatid
#uci set auto_send_file_to_telegram.sub_folder.sub_folder_name_path=/tmp/auto_send_file_to_telegram
#uci set auto_send_file_to_telegram.sub_folder.sub_folder_name=new
# Не забыть нужно применить измнения, если не сделать, а то они будут актульны лишь до перезагрузки.
# uci commit telegramopenwrt

# Удаление скрипта
# /etc/init.d/auto_send_file_to_telegram stop
# rm /etc/init.d/auto_send_file_to_telegram
# rm /etc/config/auto_send_file_to_telegram
# rm /usr/bin/auto_send_file_to_telegram.sh