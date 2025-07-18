#!/bin/sh

. /lib/functions.sh # Подключение библиотеки для работы с конфигурационными файлами
cmd_args=""
config_load auto_send_file_to_telegram # Чтение конфигурационного файла
# Из-за того, что данные берутся лишь при загрузке - редактирование скрипта не позволит боту оперативно реагировать на измнение настроек, соотвественно, для примениения изменений нужно перезапустить скрипт. Как выход, есть вариант каждый раз при проходе цикла запрашивать данные через uci, уж не знаю как скажется на производительности. https://openwrt.org/ru/docs/guide-user/base-system/uci тут можно почитать про использование UCI. А тут про использование config_get: https://openwrt.org/ru/doc/devel/config-scripting

# Посмотреть переписку с ботом можно по адресу  https://api.telegram.org/bot$BOT_TOKEN/getUpdates
config_get BOT_TOKEN bot_auth bot_token "BotToken" # Ваш токен бота, полученный от @BotFather, хранится в файле /etc/config/auto_send_file_to_telegram

config_get CHAT_ID bot_auth chat_id "ChatID" # ID пользователя, которому будут отправляться сообщения/файлы. Бот не может написать пользователю, который не писал боту сообщений или заблокировал бота.

config_get FULL_WATCH_PATH sub_folder sub_folder_name_path "/tmp/auto_send_file_to_telegram/new" # Путь к папке, которую будем мониторить на возникновение новых файлов
config_get FAILED_FILES_DIR sub_folder sub_folder_name "/tmp/auto_send_file_to_telegram/failed_files" # Путь к папке с неудачно отправленными файлами
# Скрипт создаёт две папки failed_files и $SUB_FOLDER_NAME, в каталоге $SUB_FOLDER_NAME_PATH, если этих папок ранее небыло создано в этом каталоге.

config_get_bool system_debug debug system_debug 0 # Получение информации о состоянии флага записи лога событий в системный журнал событий. Если запись велась в системный лог, то для просмотра сообщений нужно набрать logread -e auto_send_file_to_telegram

config_get_bool user_debug debug user_debug 0 # Получение информации о состоянии флага записи лога событий в пользовательский файл

config_get user_debug_path debug user_debug_path "" # Получение информации о том, в какой пользовательский файл записывать журнал событий

config_get_bool true_send global true_send 1 # Получение информации выполнять ли повторную отправку в случае неудачной отправки.

config_get_bool del_file global del_file 1 # Получение информации о том, удалять ли файлы после успешной отправки боту.

config_get_bool send_files_with_start global send_files_with_start 0 # Получении информации о том, выполнять ли автоотправку файлов из отслеживаемых папок при старте приложения.

programs="curl grep sed inotifywait jq" # перечисляю через пробел приложения, которые должны быть установлены для корретной работы скрипта

# проверка на root права у пользователя. Круто будет, если проще получится.
if [ $(id -u) -ne 0 ]; then
	echo "Скрипт должен запускаться от имени root или другого пользователя с привилегиями суперпользователя. Например, $ sudo "$0""
	if [ "$user_debug" = "1" ]; then
		{
		if [ "$user_debug_path" != "" ]; then
		echo "Скрипт должен запускаться от имени root или другого пользователя с привилегиями суперпользователя. Например, $ sudo "$0"" >> $user_debug_path
		fi
		}
	fi
	exit 1
fi

# Проверка наличия нужного для работы ПО в системе
for program in $programs; do
    if [ -z "$(opkg status "$program")" ]; then
        echo "Программа $program не установлена. Пожалуйста, установите её. Например, для установки можно использовать следующую команду: $ opkg install $program"
		
	if [ "$user_debug" = "1" ]; then
		{
		if [ "$user_debug_path" != "" ]; then
		echo "Программа $program не установлена. Пожалуйста, установите её. Например, для установки можно использовать следующую команду: $ opkg install $program" >> $user_debug_path
		fi
		}
	fi
	exit 1
	fi
done

mkdir -p $FULL_WATCH_PATH # Создание папки, которую будем мониторить
mkdir -p $FAILED_FILES_DIR # Создание папки для хранения неудачно отправленных файлов

# Функция с алгоритмом отправки файла
send_file()
{
FILE_PATH="$1" # Присвоение переменной для отправки файла $FILENAME
RESPONSE=$(curl -s -F document="@$FILE_PATH" -F chat_id="$CHAT_ID" https://api.telegram.org/bot$BOT_TOKEN/sendDocument) # Отправка файла боту
# Проверяем ответ сервера
if echo "$RESPONSE" | grep -q '"ok":true'; then

	if [ "$user_debug" = "1" ]; then
	{
		if [ "$user_debug_path" != "" ]; then
		echo "[$(date +'%Y-%m-%dT%H:%M:%SZ')] Файл "$FILE_PATH" успешно отправлен" >> $user_debug_path
		fi
	}
	fi
		
	if [ "$system_debug" = "1" ]; then
	logger -p local0.info -t auto_send_file_to_telegram "Файл "$FILE_PATH" успешно отправлен"
	fi
	
	if [ "$del_file" = "1" ]; then
	rm "$FILE_PATH" # Удаление файла в случае успешной отправки
	fi
	
else

	if [ "$user_debug" = "1" ]; then
		{
		if [ "$user_debug_path" != "" ]; then
		echo "[$(date +'%Y-%m-%dT%H:%M:%SZ')] Отправка файла "$FILE_PATH" провалилась $RESPONSE" >> $user_debug_path
		fi
		}
	fi
	
	if [ "$system_debug" = "1" ]; then
	logger -p local0.info -t auto_send_file_to_telegram "Отправка файла "$FILE_PATH" провалилась $RESPONSE"
	fi
	
	if [ "$true_send" = "1" ]; then
		{
		mv "$FILE_PATH" "$FAILED_FILES_DIR" # Перемещение файла в случае неудачной отправки в папку, с которой будут в будущем происходить ещё попытки отправки.
		}
	fi
	
fi
}

# Функция повторной отправки неудачных файлов
retry_failed_files()
	{
	if [ "$true_send" = "1" ]; then
		{
		find "$1" -type f -print0 |
		while read -d '' FAILED_FILE; do
			send_file "$FAILED_FILE"
		done
		}
	fi
	}

# Основной алгоритм скрипта

# Проверка на наличие старых неотправленных файлов при первом запуске программы и их отправка в случае успеха. Мало смысла, если данные хранятся в /tmp/ и скрипт запускается вместе с устройством, ведь файлы стираются из этих папок при каждой перезагрузке системы.
if [ "$send_files_with_start" = "1" ]; then
	{
	retry_failed_files "$FULL_WATCH_PATH"
	retry_failed_files "$FAILED_FILES_DIR"
	}
fi

# Мониторинг папки на создание новых файлов
inotifywait -m -r -e create --format '%w%f' "$FULL_WATCH_PATH" |
while read FILENAME; do
	send_file "$FILENAME"
	retry_failed_files "$FAILED_FILES_DIR"
done
# Придумать бы ещё что-то, чтобы сообщение "Setting up watches.  Beware: since -r was given, this may take a while!" не выводилось при перезапуске или запуске службы через service auto_send_file_to_telegram ...
# Так же нужно исправить недоработку. Скрипт сделан так, что попытку следущей отправки делает лишь тогда, когда выполяентся успешная отправка файла. Минус в том, что если когда не будет интернета, появится лишь один файл (или несколько файлов, главное, чтобы во время появления этих файлов интернета небыло), то будет попытка их отправки лишь только тогда, когда какой-то файл удастся отправить. А, соотвественно, если файлы появляются редко, и при появлении файлов отсутсвует интернет, то файлы не отправятся никогда. Такая логика неправильная. Есть идея с двумя параллельно работающими процессами, которые будут параллельно мониторить папки. Т.е. когда вдруг неудачная отправка, то появляется процесс, который мониторит папку FAILED_FILES_DIR. Либо, один завязан на мониториге подключения, а другой - делает отправку в случае корретного подключения к интернету. Впрочем, реализация не так проста, как кажется, поэтому я просто оставлю это в заметке, чтобы не забыть.

# Если скрипт вышел из inotifywait, то так не должно быть.

if [ "$user_debug" = "1" ]; then # Если галочка отладки стоит, то будет произведена запись log сообщений в пользовательский файл.
	{
	if [ "$user_debug_path" != "" ]; then
	echo "[$(date +'%Y-%m-%dT%H:%M:%SZ')] Работа скрипта "$0" была неожиданно завершена!" >> $user_debug_path
	fi
	}
fi

if [ "$system_debug" = "1" ]; then # Если галочка отладки стоит, то будет произведена отправка log сообщений в общий логе системы.
logger -p local0.info -t auto_send_file_to_telegram "Работа скрипта "$0" была неожиданно завершена!"
fi


exit 1
