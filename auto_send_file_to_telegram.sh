#!/bin/sh

# Ваш токен бота, полученный от @BotFather, хранится в файле /etc/config/auto_send_file_to_telegram
# Посмотреть переписку с ботом можно по адресу  https://api.telegram.org/bot$BOT_TOKEN/getUpdates
BOT_TOKEN=$(uci get auto_send_file_to_telegram.bot_auth.bot_token)
# ID пользователя, которому будут отправляться сообщения/файлы. Бот не может написать пользователю, который не писал боту сообщений или заблокировал бота.
CHAT_ID=$(uci get auto_send_file_to_telegram.bot_auth.chat_id)


# Скрипт создаёт две папки failed_files и $SUB_FOLDER_NAME, в каталоге $SUB_FOLDER_NAME_PATH, если этих папок ранее небыло создано в этом каталоге.
SUB_FOLDER_NAME_PATH=$(uci get auto_send_file_to_telegram.sub_folder.sub_folder_name_path) # Путь к папке, в которой скрипт будет хранить failed_files и $SUB_FOLDER_NAME
SUB_FOLDER_NAME=$(uci get auto_send_file_to_telegram.sub_folder.sub_folder_name) # папка, внутри которой хранятся файлы, которые нужно будет отправить
# Из-за того, что данные берутся лишь при загрузке - редактирование скрипта не позволит боту оперативно реагировать на измнение настроек, соотвественно, для примениения изменений нужно перезапустить скрипт. Как выход, есть вариант каждый раз при проходе цикла запрашивать данные через uci, уж не знаю как скажется на производительности. https://openwrt.org/ru/docs/guide-user/base-system/uci тут можно почитать про использование UCI.

# Папка, которую будем мониторить
FULL_WATCH_PATH=$(echo "/$SUB_FOLDER_NAME_PATH/$SUB_FOLDER_NAME" | sed 's/\/\{1,\}/\//g')
mkdir -p $FULL_WATCH_PATH
# Директория для хранения неудачно отправленных файлов
FAILED_FILES_DIR=$(echo "/$SUB_FOLDER_NAME_PATH/failed_files" | sed 's/\/\{1,\}/\//g')
mkdir -p $FAILED_FILES_DIR

# проверка на root права у пользователя. Круто будет, если проще получится.
isRoot() {
  if [ $(id -u) -ne 0 ]; then
    echo "Скрипт должен запускаться от имени root или другого пользователя с привилегиями суперпользователя. Например, $ sudo "$0""
    exit 1
  fi
}

# Функция с алгоритмом отправки файла
send_file() {
# Присвоение переменной для отправки файла $FILENAME
FILE_PATH="$1"
# Отправка файла боту
RESPONSE=$(curl -s -F document="@$FILE_PATH" -F chat_id="$CHAT_ID" https://api.telegram.org/bot$BOT_TOKEN/sendDocument)
# Проверяем ответ сервера
if echo "$RESPONSE" | grep -q '"ok":true'; then
# Удаление файла в случае успешной отправки
	#echo "[$(date +'%Y-%m-%dT%H:%M:%SZ')] Файл "$FILE_PATH" успешно отправлен" >> /root/auto_send_file_to_telegram.log
	#logger -p local0.info -t auto_send_file_to_telegram "Файл "$FILE_PATH" успешно отправлен"
	#Выше представлено два разные варианта отправики log сообщений. В первом - запись в файл, а во втором - обозначение в общем логе системы.
	rm "$FILE_PATH"
else
	#echo "[$(date +'%Y-%m-%dT%H:%M:%SZ')] Отправка файла "$FILE_PATH" провалилась $RESPONSE" >> /root/auto_send_file_to_telegram.log
	#logger -p local0.info -t auto_send_file_to_telegram "Отправка файла "$FILE_PATH" провалилась $RESPONSE"
	#Выше представлено два разные варианта отправики log сообщений. В первом - запись в файл, а во втором - обозначение в общем логе системы.
	mv "$FILE_PATH" "$FAILED_FILES_DIR/"
fi
}

# Функция повторной отправки неудачных файлов
retry_failed_files() {
	find "$1" -type f -print0 |
	while read -d '' FAILED_FILE; do
		send_file "$FAILED_FILE"
	done
}

# Основной алгоритм скрипта

# Проверка на наличие старых неотправленных файлов и их отправка в случае успеха (не имеет смысла, если данные хранятся в tmp)
retry_failed_files "$FULL_WATCH_PATH"
retry_failed_files "$FAILED_FILES_DIR"

# Проверка на наличия нужного для работы ПО в системе
isRoot
checkPrograms

# Мониторинг папки на создание новых файлов
inotifywait -m -r -e create --format '%w%f' "$FULL_WATCH_PATH" |
while read FILENAME; do
	send_file "$FILENAME"
	retry_failed_files "$FAILED_FILES_DIR"
done

# Если скрипт вышел из inotifywait, то так не должно быть.
#echo "[$(date +'%Y-%m-%dT%H:%M:%SZ')] Работа скрипта "$0" была неожиданно завершена!" >> /root/auto_send_file_to_telegram.log
#logger -p local0.info -t auto_send_file_to_telegram "Работа скрипта "$0" была неожиданно завершена!"
#Выше представлено два разные варианта отправики log сообщений. В первом - запись в файл, а во втором - обозначение в общем логе системы.
exit 1

# Для активации записи событий нужно раскомментировать строки, содержащие >> /root/auto_send_file_to_telegram.log. Кстати, название и место хранения файла можно выбрать любое.
# Если запись велась в системный лог, то для просмотра сообщений нужно набрать logread -e auto_send_file_to_telegram