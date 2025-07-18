#!/bin/sh

# Этот скрипт лишь умеет делать установочный ipk файл веб интерфейса LuCI для приложения auto_send_file_to_telegram: https://github.com/Denis11212/auto_send_file_to_telegram

# Из существенных недоработок и недоделок отмечу, что галочка автозапуска в веб интерфейсе Luci не работает. Так же при нажатии кнопки "применить изменения" в интерфейсе LuCI сами измненения хоть и записываются в UCI файл настроек /etc/config/auto_send_file_to_telegram, но программа не перезапускается сама, соотвественно, перезапускать придётся вручную. Так же в веб интерфейсе не отображается статус работы службы auto_send_file_to_telegram, нет возможности перезапустить auto_send_file_to_telegram, а часть функционала вообще не реализована. Например, неплохо было бы добавить больше информативности к командам. Так же классно смотрится мониторинг занятого места файлами в папках отправки и ожидания отправки.
# По этой причине, при каждом изменении настроек в LuCI нужно нажать "применить", а потом перезапустить сервис командой "service auto_send_file_to_telegram restart".

auto_send_file_to_telegramLuciSource="auto_send_file_to_telegramLuciSource" # папка, в которой будет создаваться файловая система ipk установочника веб интерфейса

auto_send_file_to_telegramSource="auto_send_file_to_telegramSource" # папка, в которой будет создаваться файловая система ipk установочника

script_URL='https://github.com/Denis11212/auto_send_file_to_telegram/raw/refs/heads/main/auto_send_file_to_telegram.sh' # адрес загрузки скрипта

# Скачивание актуальной версии скрипта по сборке установочника
UpdateScript()
{
echo "Происходит загрузка скрипта для сборки ipk пакета ipkg-build, подождите…"
curl -Ls -O "https://github.com/openwrt/openwrt/raw/refs/heads/main/scripts/ipkg-build"
chmod +x ./ipkg-build
}

compileauto_send_file_to_telegram()
{

# Загрузка свежей версии скрипта из GitHub.
echo "Происходит загрузка auto_send_file_to_telegram, подождите…"
mkdir -p "$auto_send_file_to_telegramSource"/usr/bin/
curl -Ls -o "$auto_send_file_to_telegramSource"/usr/bin/auto_send_file_to_telegram.sh "$script_URL"

	# Создаение файлов с настройками управления сервисами. Подробнее про управление сервисами в openwrt можно почитать тут: https://openwrt.org/docs/guide-user/base-system/managing_services
mkdir -p "$auto_send_file_to_telegramSource"/etc/init.d/
	cat << 'EOF' > "$auto_send_file_to_telegramSource"/etc/init.d/auto_send_file_to_telegram	# Файл для управления сервисом auto_send_file_to_telegram (тут описаны действия при запуске, остановке, перезапуске и так далее)
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


mkdir -p "$auto_send_file_to_telegramSource"/etc/config/
	cat << 'EOF' > "$auto_send_file_to_telegramSource"/etc/config/auto_send_file_to_telegram # Создаение файла с настройками UCI
config auto_send_file_to_telegram 'global'
  option autostart '1'
  option true_send '1'
  option del_file '1'
  
config auto_send_file_to_telegram 'bot_auth'
  option bot_token 'BOT_TOKEN'
  option chat_id 'CHAT_ID'

config auto_send_file_to_telegram 'sub_folder'
  option sub_folder_name_path '/tmp/auto_send_file_to_telegram/new'
  option sub_folder_name '/tmp/auto_send_file_to_telegram/failed_files'
  
config auto_send_file_to_telegram 'debug'
  option user_debug_path '/tmp/auto_send_file_to_telegram/auto_send_file_to_telegram.log'
EOF

mkdir -p "$auto_send_file_to_telegramSource"/CONTROL/
	cat << 'EOF' > "$auto_send_file_to_telegramSource"/CONTROL/postinst	# Создание файла с действиями после установки (обычный sh скрипт)
#!/bin/sh

service auto_send_file_to_telegram enable
service auto_send_file_to_telegram start
EOF

	cat << 'EOF' > "$auto_send_file_to_telegramSource"/CONTROL/prerm	# Создание файла с действиями перед удалением (обычный sh скрипт)
#!/bin/sh

service auto_send_file_to_telegram stop
service auto_send_file_to_telegram disable
EOF

	cat << EOF > "$auto_send_file_to_telegramSource"/CONTROL/control # Далее нужно внимательно проверить, верна ли информация, указанная ниже в файле control. Обязательно должны присутсвовать разделы Package, Version, Architecture, Maintainer, Description, хотя насчёт Description и Maintainer я не уверен, впрочем, может и ещё меньше можно оставить полей. Но лишняя информация вряд-ли повредит, особенно если она верно указана. Скрипт ipkg-build умеет заполнять Installed-Size автоматически. Так же можно использовать ещё в control файле ipk пункт Depends:, в котором можно указазать от каких других пакетов зависит данный пакет для своей работы. SourceDateEpoch: как я понял, это в формате Unix time время крайнего измнения исходного кода.
Package: auto_send_file_to_telegram
Version: 1.0
Depends: curl grep sed inotifywait jq
Source: feeds/packages/auto_send_file_to_telegram
SourceName: auto_send_file_to_telegram
License: none
LicenseFiles: no
Section: net
SourceDateEpoch: 51251413
Architecture: all
URL: https://github.com/Denis11212/auto_send_file_to_telegram
Maintainer: Denis11212 <denis2371@gmail.com>
Installed-Size: 
Description: This script is designed to automatically send all new files that appear in the desired folder to the telegram bot.
EOF

# Выдача разрешений файлам

chmod +x "$auto_send_file_to_telegramSource"/usr/bin/auto_send_file_to_telegram.sh
chmod +x "$auto_send_file_to_telegramSource"/etc/init.d/auto_send_file_to_telegram
chmod 600 "$auto_send_file_to_telegramSource"/etc/config/auto_send_file_to_telegram
chmod +x "$auto_send_file_to_telegramSource"/CONTROL/postinst
chmod +x "$auto_send_file_to_telegramSource"/CONTROL/prerm
chmod +x "$auto_send_file_to_telegramSource"/CONTROL/postrm
}

compileauto_send_file_to_telegramLuci() # Создание файлов и комплияция пакета для оболочки LuCI
{
mkdir -p "$auto_send_file_to_telegramLuciSource"/www/luci-static/resources/view/
	cat << 'EOF' > "$auto_send_file_to_telegramLuciSource"/www/luci-static/resources/view/auto_send_file_to_telegram.js	# Создание файла на языке JavaScript для отрисовки веб интерфейса.
'use strict';
'require form';

return L.view.extend({
    render: function () {
        var m, s, o;

        m = new form.Map('auto_send_file_to_telegram', 'Telegram OpenWrt File Sender');

s = m.section(form.NamedSection, 'global', 'auto_send_file_to_telegram', 'Основные настройки');
        o = s.option(form.Flag, 'autostart', 'Автоматический запуск при загрузке системы');
        o = s.option(form.Flag, 'true_send', 'Пытаться ли отправить файлы позже, в случае первой неудачной отправки');
			o.description = 'Если файл отправить не удаётся, то скрипт перемещает файл в папку с неудачно отправленными файлами, и затем (при определённых обстоятельствах) будет пытаться отправить этот файл снова.';
        o = s.option(form.Flag, 'del_file', 'Удаление файлов в случае успешной отправки');
			o.description = 'Как только файл будет успешно отправлен боту, то файл будет удалён. Полезно для экономии памяти.';
        o = s.option(form.Flag, 'send_files_with_start', 'Отправка всех файлов, хранящихся в основной папке и папке с ошибочными отправлениями, при каждой первичной загрузке скрипта');
			o.description = `Если файлы хранятся в оперативной памяти и скрипт запускается вместе с устройством, то можно убрать переключатель, ведь файлы стираются из оттуда при каждой перезагрузке системы. Кстати, если не включено удаление файлов в случае успешной отправки, то каждый раз при первом запуске скрипта будут отправлены все файлы, хранящиеся в отслеживаемой папке и папке с неудачно отправленными файлами`;

s = m.section(form.NamedSection, 'bot_auth', 'auto_send_file_to_telegram', 'Настройка бота');
        o = s.option(form.Value, 'bot_token', 'Bot token');
			o.description = `
В этом поле нужно указать токен бота. Если не знаете что это такое, то <abbr title="Инструкция по созданию бота в Телеграмм:
        1. Открыть Telegram и найти @BotFather. Либо, можно просто запустить чат с ботом по ссылке: https://telegram.me/botfather или ткнуть на @BotFather по тексту дальше.
        2. Начать чат с BotFather и следовать инструкциям для создания нового бота. Если написать /start, то бот отправит список поддерживаемых команд. Команда /newbot создаст нового бота, её и нужно ввести.
        3. «Alright, a new bot. How are we going to call it? Please choose a name for your bot.» - это предлагают выбрать имя для бота. Можно ввести любое, но нужно чтобы было уникальное.
        4. «Good. Now let's choose a username for your bot. It must end in 'bot'. Like this, for example: TetrisBot or tetris_bot.» - это предлагают ввести имя пользователя, которое будет использоваться для формирования ссылки на бота. Оно должно состоять из латинских символов, исключены пробелы. И самое главное, три последние буквы должны быть …bot.
        5. Когда бот будет создан, BotFather выдаст токен для доступа к API. Он будет написан в следущей строке после «Use this token access the HTTP API:». Если тапнуть на этот токен, то этот токен будет скопирован в буфер обмена.
        6. Необходимо написать несколько сообщений боту, чтобы скрипт смог извлечь ваш CHAT_ID.

Больше информации можно найти в официальной документации по этой ссылке"><a href="https://core.telegram.org/bots/api#authorizing-your-bot" target="_blank">создайте своего бота</a></abbr> через <a href="https://t.me/BotFather" target="_blank">@BotFather</a> и получите <abbr title="Пример: 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11">Bot token</abbr>. Затем вставьте в поле выше токен вашего бота.
`;

        o = s.option(form.Value, 'chat_id', 'Chat ID');
			o.description = `
Получите <abbr title="Больше информации в официальной документации"><a href="https://core.telegram.org/api/bots/ids#chat-ids" target="_blank">Chat ID</a></abbr> своего акаунта. Затем вставьте свой <abbr title="Пример: 123456789">Chat ID</abbr> в поле выше. Важно отметить, что чтобы бот мог общаться с вами, вам необходимо отправить одно сообщение боту с аккаунта, чей Chat ID вы указали.
`;

s = m.section(form.NamedSection, 'sub_folder', 'auto_send_file_to_telegram', 'Хранилище');
        o = s.option(form.Value, 'sub_folder_name_path', 'Путь к отслеживаемой скриптом папке');
			o.placeholder = '/tmp/auto_send_file_to_telegram/new';
        o = s.option(form.Value, 'sub_folder_name', 'Путь к папке с неудачно отправленными файлами');
			o.placeholder = '/tmp/auto_send_file_to_telegram/failed_files';

s = m.section(form.NamedSection, 'debug', 'auto_send_file_to_telegram', 'Отладка');
        o = s.option(form.Flag, 'system_debug', 'Отправка событий в систему OpenWrt');
 o.description = `Для просмотра этих сообщений нужно выполнить команду <code>logread -e auto_send_file_to_telegram</code> в теримнале`;
        o = s.option(form.Flag, 'user_debug', 'Запись событий в пользовательский файл');
                var extra = s.option(form.Value, 'user_debug_path', 'Путь к файлу пользовательского журнала событий');
                extra.depends('user_debug', '1');

o = s.option(form.DummyValue, '_toggle_btn', 'Справка по программе и конфеденциальности хранимых данных ботом');
o.rawhtml = true;
o.cfgvalue = function () {
    return `
        <button class="btn" onclick="
            var btnText = this.textContent.trim();
            var section = document.getElementById('advanced_section');

            if(section.style.display === 'none'){
                section.style.display = 'block';
                this.textContent = 'Закрыть';
            } else{
                section.style.display = 'none';
                this.textContent = 'Открыть';
            }
        ">Open</button>

        <div id="advanced_section" style="display:none; margin-top:10px;">
        <p>Хранить BOT_TOKEN следует в секрете, так как он позволяет получить полный доступ к боту! BOT_TOKEN состоит из двух частей: ID_бота:ключ_бота. Для доступа к данным бота используется команда, объединяющая ID и TOKEN. Соединив обе части в специальном url запросе, можно получить доступ ко всем перепискам бота за определённый период времени (насколько знаю, менее 24 часов), а также доступно будет 100 последних сообщений. Соотвественно, если кто-то овладеет вышеобозначенной информацией, а вернее, BOT_TOKEN, то он сможет получить доступ ко всем данным, но, всё-таки будет скован вышеописанными ограничениями по времени хранения и количеству сообщений. Однако, никто не мешает вести логгирование сообщений после получения доступа к боту. Ну и политика телеграмм может со временем измениться.</p>
        <p>CHAT_ID является индивидуальным номером, и присваивается каждому новому пользователю. Любой телеграмм бот, которому пишет пользователь, получает CHAT_ID этого пользователя. CHAT_ID обозначается в поле id каждого сообщения от пользователя, рядом с другой информацией, если пользователь её о себе сообщаете (это в настройках клиента телеграмм задаётся). Я не знаю, меняется ли CHAT_ID, но если и меняется, то крайне редко. А тот факт, что у более старых пользователей CHAT_ID более короткий, чем у новых, это позволяет сделать предположение, что такой числовой идентификатор присваивается навсегда. Так что CHAT_ID вычислить не сложно, впрочем, это и не является секретной информацией. Кстати, если боту будут писать несколько пользователей, то бот будет хранить несколько чатов, доступ к которым можно получить полностью зная BOT_TOKEN (и то, там имеются ограничения, обозначенные абзацем выше). Самим же пользователям будет доступен их индивдульный чат с ботом, соотвественно, они не смогут увидеть переписки друг друга.</p>
        <p>По умолчанию боты доступы через поиск телеграмм, а значит им может написать кто угодно, создав новый чат. Так что нужно быть аккуратнее. Впрочем, без BOT_TOKEN к личным перепискам с ботом получить вряд-ли удастся, так как для каждого пользователя появятся новые изолированные чаты, которые, кроме пользователя, может прочитать лишь тот, кто владеет BOT_TOKEN. Но при настройке бота я всё-таки советую внимательно относиться какой CHAT_ID вы вводите. Разумеет, узнав свой CHAT_ID единажды, можно уже создавать ботов, писать им любое сообщение, например, /start, а затем без всяких там парсеров по получению CHAT_ID сразу задавать свой личный CHAT_ID и BOT_TOKEN, тем самым получив полноценный доступ к переписке с ботом. Кстати, если боту задать CHAT_ID пользователя, который не писал этому боту, то бот не сможет связаться и выдаст ошибку. Ну или если бота заблокирует ранее написавший боту пользователь, то тоже будет ошибка..</p>
        </div>
    `;
};

return m.render();
    }
});
EOF

mkdir -p "$auto_send_file_to_telegramLuciSource"/usr/share/rpcd/acl.d/
	cat << 'EOF' > "$auto_send_file_to_telegramLuciSource"/usr/share/rpcd/acl.d/luci-app-auto_send_file_to_telegram.json	# Создание структуры доступа к разным действиям и папкам для JavaScript файла программы.
{
        "luci-app-auto_send_file_to_telegram": {
                "description": "Grant access to cat Telegram OpenWrt config",
                "read": {
                        "uci": [
                                "auto_send_file_to_telegram"
                        ]
                },
                "write": {
                        "uci": [
                                "auto_send_file_to_telegram"
                        ]
                }
        }
}
EOF

mkdir -p "$auto_send_file_to_telegramLuciSource"/usr/share/luci/menu.d/
	cat << 'EOF' > "$auto_send_file_to_telegramLuciSource"/usr/share/luci/menu.d/luci-app-auto_send_file_to_telegram.json	# Создание структуры меню, т.е. в каком разделе LuCI искать программу.
{
        "admin/services/auto_send_file_to_telegram": {
                "title": "Telegram File Sender",
                "action": {
                        "type": "view",
                        "path": "auto_send_file_to_telegram"
                },
                "depends": {
                        "acl": [ "luci-app-auto_send_file_to_telegram" ],
                        "uci": { "auto_send_file_to_telegram": true }
                }
        }
}
EOF

mkdir -p "$auto_send_file_to_telegramLuciSource"/CONTROL/
	cat << EOF > "$auto_send_file_to_telegramLuciSource"/CONTROL/control	# Далее нужно внимательно проверить, верна ли информация, указанная ниже в файле control. Обязательно должны присутсвовать разделы Package, Version, Architecture, Maintainer, Description, хотя насчёт Description и Maintainer я не уверен, впрочем, может и ещё меньше можно оставить полей. Но лишняя информация вряд-ли повредит, особенно если она верно указана. Скрипт ipkg-build умеет заполнять Installed-Size автоматически. Так же можно использовать ещё в control файле ipk пункт Depends:, в котором можно указазать от каких других пакетов зависит данный пакет для своей работы. SourceDateEpoch: как я понял, это в формате Unix time время крайнего измнения исходного кода.
Package: luci-app-auto_send_file_to_telegram
Version: 1.0
Depends: auto_send_file_to_telegram
Source: feeds/packages/luci-app-auto_send_file_to_telegram
SourceName: luci-app-auto_send_file_to_telegram
License: none
LicenseFiles: no
Section: luci
SourceDateEpoch: 37753245
Architecture: all
URL: https://github.com/Denis11212/auto_send_file_to_telegram
Maintainer: Denis11212 <denis2371@gmail.com>
Installed-Size: 
Description: Its a web interface for script auto_send_file_to_telegram.
EOF
}


# Основной алгоритм действий скрипта!

UpdateScript

compileauto_send_file_to_telegram # Делаем структуру папок и файлов для IPK
echo "Происходит сборка auto_send_file_to_telegram , подождите…"
./ipkg-build "$auto_send_file_to_telegramSource/" # Сборка пакета
rm -rf "$auto_send_file_to_telegramSource" # Удаление папки, используемой для сборки, за ненадобностью.

# Сборка пакета для LuCI
compileauto_send_file_to_telegramLuci # Делаем структуру папок и файлов для модуля к LuCI
echo "Происходит сборка дополнения auto_send_file_to_telegram для LuCI, подождите…"
./ipkg-build "$auto_send_file_to_telegramLuciSource/" # Сборка пакета
rm -rf "$auto_send_file_to_telegramLuciSource" # Удаление папки, используемой для сборки LuCI дополнения за ненадобностью.

rm -rf ipkg-build # Удаление файла создаения IPK файлов. Но сам скрипт и созданные файлы для разных архитектур остаются.

#Диалог выхода из программы с предложением удалить файлы.
while true; do
	read -rp "Работа скрипта завершена. Удалить ли теперь и сам скрипт "$0"? [Д/н]: " answer
	case "$answer" in
		""|Д|д|Да|да|Y|y|Yes|yes)
			rm -rf "$0"
			exit 0
			;;
		Н|н|Нет|нет|N|n|No|no)
			exit 0
			;;
		*)
			echo "Неправильный ввод. Попробуйте еще раз."
			continue
			;;
		esac
done
