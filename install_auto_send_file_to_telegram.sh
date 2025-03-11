#!/bin/sh

# Классно было бы вообще в LuCI интегрировать хотя бы такой функционал для начала, но я не умею этого делать. Так что если кто-то умеет, то вот вам идея.

config_file="/usr/bin/auto_send_file_to_telegram.sh" # Исполняемый файл скрипта auto_send_file_to_telegram
script_file="/etc/config/auto_send_file_to_telegram" # Файл хранения данных auto_send_file_to_telegram
script_URL='https://github.com/Denis11212/auto_send_file_to_telegram/raw/refs/heads/main/auto_send_file_to_telegram.sh' # адрес загрузки скрипта
programs="curl grep sed inotifywait find jq" # перечисляю через пробел приложения, которые должны быть установлены.

isRoot() {
  if [ $(id -u) -ne 0 ]; then
    echo "Скрипт должен запускаться от имени root или другого пользователя с привилегиями суперпользователя. Например, $ sudo "$0""
    exit 1
  fi
}

# Для своей работы скрипт использует следущие приложения, перечисленные в переменной $programs. Так же скрипту нужно соединения с интернетом, обязательно проверьте его.
checkPrograms() {
for program in $programs; do
    if ! command -v "$program" > /dev/null; then
        echo "Программа $program не установлена. Пожалуйста, установите её. Например, для установки можно использовать следующую команду: $ opkg install $program"
        exit 1
    fi
done
}

check_install() {
if ! [ -f "$config_file" ]; then
	echo "Файл $config_file не найден."
	install_tgbot
elif ! [ -f "$script_file" ]; then
	echo "Скрипт $script_file не обнаружен в системе."
	install_tgbot
fi
}

show_help() {
    cat << EOF
Использование: $(basename $0) [ОПЦИЯ1] [ОПЦИЯ2]

Описание: Это устновочный файл скрипта, который умеет мониторить выбранную пользователем папку, и, в случае появления там новых файлов тут же отправлять эти файлы телеграмм боту. При настройке скрипт способен, например, определять CHAT_ID по вашему BOT_ID. Для быстрого взаимодействия прикрутил сюда поддержку аргументов.
Официальные страницы этого скрипта
На GitHub: https://github.com/Denis11212/auto_send_file_to_telegram

Опции:
	-h, --help		Показать эту справку и выйти.
	-d, --delete	Удаление скрипта из системы.

Примеры:
  sudo $(basename $0) токен_бота идентификатор_чата	Записать в $config_file новые данные о боте.
  $(basename $0) -h									Вывести справку
  
Краткая инструкция по использованию:
	Для любых действий по измнению данных файла $config_file нужны права суперпользователя, так как файл этот файл содержит данные Телеграмм бота, которые позволят получить доступ к телеграмм боту кому угодно. Все поддерживаемые аргументы перечислены в разделе "Опции". Если запускать скрипт без аргументов, то он сам всё что нужно для подключения к боту файла $config_file спросит. Если же приложение auto_send_file_to_telegram не установлено, то скрипт самостоятельно установит это приложение. Для опытных пользователей имеется возможность быстро настроить файл $config_file, задав первым аргументом [ОПЦИЯ1], он же BOT_ID, он же токен бота, а вторым [ОПЦИЯ2], он же CHAT_ID, он же является идентификатором чата отдельного пользователя. Впрочем, можно задать и только BOT_ID первым аргументом. Скрипт поймёт и будет пытаться определить CHAT_ID. Подробнее о CHAT_ID и BOT_ID читайте ниже.
	Это окно со справкой можно всегда вызвать командой $ "$0" -h. Кстати, вывод справки не требует прав суперпользователя.

Немного о телеграмм ботах и конфеденциальности хранимых данных ботом
	Храните ваш BOT_TOKEN в секрете, так как он позволяет получить полный доступ к вашему боту! BOT_TOKEN состоит из двух частей: ID_бота:ключ_бота. Для доступа к данным бота используется команда, объединяющая ID и TOKEN. Соединив обе части в специальном url запросе, можно получить доступ ко всем перепискам бота за определённый период времени (насколько знаю, менее 24 часов), а также доступно будет 100 последних сообщений. Соотвественно, если кто-то овладеет вышеобозначенной информацией, а вернее, вашим BOT_TOKEN, то он сможет получить доступ ко всем данным, но, всё-таки будет скован вышеописанными ограничениями по времени хранения и количеству сообщений. Однако, никто не мешает вести логгирование сообщений после получения доступа к боту.
	CHAT_ID является индивидуальным номером, и присваивается каждому новому пользователю. Любой телеграмм бот, которому вы пишите, получает ваш CHAT_ID. CHAT_ID обозначается в поле id каждого вашего сообщения, рядом с другой информацией, если вы её о себе сообщаете. Я не знаю, меняется ли CHAT_ID, но если и меняется, то крайне редко. А тот факт, что у более старых пользователей CHAT_ID более короткий, чем у новых, позволяет сделать предположение, что этот числовой идентификатор присваивается навсегда. Так что ваш CHAT_ID вычислить не сложно, впрочем, это и не является секретной информацией. Если боту будут писать несколько пользователей, то бот будет хранить несколько чатов, доступ к которым можно получить полностью зная BOT_TOKEN (и то, там имеются ограничения, обозначенные абзацем выше). Самим же пользователям будет доступен изолированный чат с вашим ботом, они не смогут увидеть переписки друг друга.
	По умолчанию боты доступы через поиск телеграмм, а, соотвественно, им может написать кто угодно, создав новый чат. Так что будьте аккуратнее. Впрочем, без BOT_TOKEN к вашим личным перепискам с ботом получить вряд-ли удастся, просто появятся новые чаты, которые будет видно через BOT_TOKEN. Но при настройке бота я всё-таки советую внимательно относиться какой CHAT_ID вы вводите. Узнав свой CHAT_ID единажды, можно уже создавать ботов, писать /start, а затем без всяких там парсеров сразу задавать свои личные BOT_TOKEN и CHAT_ID, тем самым получив полноценный доступ к переписке с ботом. Кстати, если боту задать CHAT_ID пользователя, который не писал этому боту, то бот не сможет связаться и выдаст ошибку. Ну и если бота заблокирует ранее написавший боту пользователь, то тоже будет ошибка.
EOF
}

show_instruction_bot() {
    cat << EOF
Инструкция по созданию бота в Телеграмм:
	1. Открыть Telegram и найти @BotFather. Либо, можно просто запустить чат с ботом по ссылке: https://telegram.me/botfather
	2. Начать чат с BotFather и следовать инструкциям для создания нового бота. Если написать /start, то бот отправит список поддерживаемых команд. Команда /newbot создаст нового бота, её и нужно ввести.
	3. «Alright, a new bot. How are we going to call it? Please choose a name for your bot.» - это предлагают выбрать имя для бота. Можно ввести любое, но нужно чтобы было уникальное.
	4. «Good. Now let's choose a username for your bot. It must end in 'bot'. Like this, for example: TetrisBot or tetris_bot.» - это предлагают ввести имя пользователя, которое будет использоваться для формирования ссылки на бота. Оно должно состоять из латинских символов, исключены пробелы. И самое главное, три последние буквы должны быть …bot.
	5. Когда бот будет создан, BotFather выдаст токен для доступа к API. Он будет написан в следущей строке после «Use this token access the HTTP API:». Если тапнуть на этот токен, то этот токен будет скопирован в буфер обмена.
	6. Необходимо написать несколько сообщений боту, чтобы скрипт смог извлечь ваш CHAT_ID.
EOF
}

# Получение данных для доступа к боту телеграмм.
get_data() {
  if [ -z "$BOT_TOKEN" ]; then
    show_instruction_bot
  elif [ -n "$BOT_TOKEN" ]; then
    # Проверяем корректность BOT_TOKEN
    response=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getMe")
    
    if echo "$response" | grep -q '"ok":false'; then
      echo "Неверный BOT_TOKEN. Повторите ввод."
      show_instruction_bot
      BOT_TOKEN=""
    fi
  fi
  
  response=""
  local error=false
  
  while true; do
    if [ -z "$BOT_TOKEN" ]; then
      read -p "Токен бота (BOT_TOKEN): " BOT_TOKEN
    fi
    
    # Проверяем корректность BOT_TOKEN
    response=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getMe")
    
    if echo "$response" | grep -q '"ok":false'; then
      echo "Неверный BOT_TOKEN. Повторите ввод."
      BOT_TOKEN=""
      continue
    fi
    
    if [ -z "$CHAT_ID" ]; then
      read -p "Введите идентификатор чата (CHAT_ID) (можно пропустить, нажав, Enter, если неизвестно): " CHAT_ID
    fi
    
    while [ -z "$CHAT_ID" ]; do
      # Получаем обновления от API Telegram
      response=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates")
      
      # Проверяем успешность запроса
      if echo "$response" | grep -q '"ok":false'; then
        echo "Ошибка при получении обновлений от API Telegram. Проверьте правильность BOT_TOKEN."
        error=true
        break
      fi
      
      # Извлекаем последний CHAT_ID
      CHAT_ID=$(echo "$response" | jq -r '.result[-1].message.chat.id // empty')
      
      if [ -z "$CHAT_ID" ]; then
        if [ "$first_time" != "true" ]; then
          echo "Ожидается получение CHAT_ID… Для этого нужно написать боту сообщение. Как только CHAT_ID будет получен, скрипт продолжит свою работу…"
          first_time="true"
        fi
        sleep 10
      else
        break
      fi
    done
    
    if [ "$error" = false ]; then
      break
    fi
	
    error=false
    BOT_TOKEN=""
    CHAT_ID=""
    first_time=""
  done
}

install_tgbot() {
while true; do
		echo -n "Вероятно, auto_send_file_to_telegram не установлен. Скачать и установить? [Д/н]: "
		read answer
		case "$answer" in
			""|Д|д|Да|да|Y|y|Yes|yes)
				echo "Приложение и его поддержка доступна по адресу https://github.com/Denis11212/auto_send_file_to_telegram"
				install_script
				break;;
			Н|н|Нет|нет|N|n|No|no)
				echo "Работа скрипта была завершена без внесения измнений. После самостоятельной установки приложения, например, с официального репозитория https://github.com/Denis11212/auto_send_file_to_telegram вы можете снова запустить скрипт $0 для интеграции данных вашего телеграмм бота в приложение."
				exit 0
				;;
			*)
			echo "Неправильный ввод. Попробуйте еще раз."
			continue
			;;
		esac
	done
}

install_script () {
echo "Происходит загрузка auto_send_file_to_telegram, подождите…"
curl -Ls -o "/usr/bin/auto_send_file_to_telegram.sh" "$script_URL"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] ; then
get_data
fi

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
  option bot_token '$BOT_TOKEN'
  option chat_id '$CHAT_ID'

config auto_send_file_to_telegram 'sub_folder'
  option sub_folder_name_path '/tmp/auto_send_file_to_telegram'
  option sub_folder_name 'new'
EOF

# Командами нужно дать права
chmod +x /usr/bin/auto_send_file_to_telegram.sh
chmod +x /etc/init.d/auto_send_file_to_telegram
chmod 600 /etc/config/auto_send_file_to_telegram

/etc/init.d/auto_send_file_to_telegram enable # Добавить скрипт в автозагрузку
echo "Скрипт был успешно установлен в систему. После установки ваше устройство будет перезагружено. 
Скрипт использует запись данных в выбранную вами область памяти. Частая перезапись во Flash-память устройства может привести к её износу. Хранение данных в ОЗУ избавит от этой проблеммы, но оно ненадёжно из-за потери данных при отключении питания. Можно использовать внешние накопители, такие как MicroSD, NVMe, HDD или USB-флэшки с хорошим ресурсом и/или если вам их не жалко. Ведь если выйдет из строя Nand память на роутере, то её замена относительно сложная и дорогая. В некоторых случаях проще или дешевле будет купить новый роутер.
Пути хранения данных можно поменять в файле настроек /etc/config/auto_send_file_to_telegram. Чтобы применить изменения внесённые в этот файл можно, например, перезагрузить устройство командой reboot. По умполчанию (после установки) скрипт мониторит папку /tmp/auto_send_file_to_telegram/new/"
reboot # Перезапустить устройство
# /etc/init.d/auto_send_file_to_telegram start # не вижу смысла запускать, лучше выполнить reboot перезагрузку
exit 0 # Вероятно, смысла нет, однако, на всякий случай пусть будет тут для вида. Пологаю, но могу ошибаться, что после reboot скрипт уже не будет исполняться.
}

# Удаление скрипта
uninstall_script () {
/etc/init.d/auto_send_file_to_telegram stop
rm /etc/init.d/auto_send_file_to_telegram
rm /etc/config/auto_send_file_to_telegram
rm /usr/bin/auto_send_file_to_telegram.sh
echo "Скрипт полностью удалён из системы, если был ранее установлен"
}

write_data() {
# Не знаю достаточно ли перезапускать лишь сам сервис, но пока вроде работает корректно
/etc/init.d/auto_send_file_to_telegram stop
# Можно почитать про использование UCI на https://openwrt.org/ru/docs/guide-user/base-system/uci
uci set auto_send_file_to_telegram.bot_auth.bot_token=$BOT_TOKEN
uci set auto_send_file_to_telegram.bot_auth.chat_id=$CHAT_ID
uci commit auto_send_file_to_telegram
reboot # Перезапустить устройство
# /etc/init.d/auto_send_file_to_telegram start # не вижу смысла запускать, лучше выполнить reboot перезагрузку
}

# Основной алгоритм скрипта по установке

case "$1" in
  -h|--help)
    show_help
    exit 0;;
  -d|--delete)
    isRoot
	uninstall_script
    exit 0;;
esac

checkPrograms
isRoot

BOT_TOKEN=$1
CHAT_ID=$2

check_install

# Блоки с действиями
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] ; then
get_data
fi
write_data

# Получаем список всех ID чатов, работает пока немного странно. Так, например, в некоторых запросах на curl выдаёт не полностью страницу, а лишь первое сообщение с ID первого чата, но которое было выполненено не позднее чем спустя несколько часов от выполнения запроса. 
chat_list=$(echo $response | jq -r '.result[] | (.message // .my_chat_member).chat.id // empty' | sort -u)

# Вывод данных и завершение работы скрипта
echo "Теперь в файле $script_file на строчке $(grep -Fn "$BOT_TOKEN" "$config_file" | cut -d: -f1) присвоено значение $BOT_TOKEN, а на строчке $(grep -Fn "$CHAT_ID" "$config_file" | cut -d: -f1) в этом же файле присовено $CHAT_ID. Так нужно для использования бота скриптом. Все, кто сможет открыть файл и прочитать значение BOT_TOKEN - смогут тоже использовать бота.
Отмечу, что только пользователь с правами root сможет просматривать, изменять и исполнять файл "$config_file". Чтобы другой пользователь мог просмотреть содержимое файла "$config_file", ему потребуется переключиться на учетную запись root (например, с помощью команды sudo) или получить специальные привилегии, предоставленные администратором системы.
Список некоторых других чатов вашего бота, которые удалось обнаружить (каждый чат соотвествует ID пользователя, написавшего боту): $(echo "$chat_list" | tr '\n' ' ')"
exit 0

# А вот так просто, можно извлекать данные из конфигурационного файла, вдруг где-то пригодится.
# uci get auto_send_file_to_telegram.bot_auth.bot_token
# uci get auto_send_file_to_telegram.bot_auth.chat_id

# Пример упрвления через uci, в котором выставляются нужные параметры
#uci set auto_send_file_to_telegram.bot_auth.bot_token=bottoken
#uci set auto_send_file_to_telegram.bot_auth.chat_id=chatid
#uci set auto_send_file_to_telegram.sub_folder.sub_folder_name_path=/tmp/auto_send_file_to_telegram
#uci set auto_send_file_to_telegram.sub_folder.sub_folder_name=new
# Не забыть нужно применить измнения, если не сделать, то они будут актульны лишь до перезагрузки.
# uci commit auto_send_file_to_telegram
# https://openwrt.org/ru/docs/guide-user/base-system/uci тут можно почитать про использование UCI
