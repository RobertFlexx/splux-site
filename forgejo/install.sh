#!/bin/sh
# Install Splux Git (Forgejo) on this host and copy the Splux theme.
# Does not create an admin user or access token.
# Usage: sh forgejo/install.sh
set -eu

SITE=$(CDPATH= cd -P "$(dirname "$0")/.." && pwd) || exit 1
FORGE=${FORGE:-/home/robert/splux-forge}
THEME=$SITE/forgejo
DATA=$FORGE/data
CONF=$DATA/custom/conf/app.ini
BIN=$FORGE/bin/forgejo
FJ() {
	"$BIN" -w "$DATA" -c "$CONF" "$@"
}

[ -x "$BIN" ] || {
	printf '%s\n' "missing $BIN" >&2
	exit 1
}

mkdir -p "$DATA/custom/conf" "$DATA/custom/public/assets/css" \
	"$DATA/custom/public/assets/img" "$DATA/custom/templates/custom" \
	"$FORGE/log"

install_theme() {
	cp "$THEME/theme-splux.css" "$DATA/custom/public/assets/css/theme-splux.css"
	cp "$THEME/templates/custom/extra_links.tmpl" \
		"$DATA/custom/templates/custom/extra_links.tmpl"
	cp "$THEME/templates/custom/extra_links_footer.tmpl" \
		"$DATA/custom/templates/custom/extra_links_footer.tmpl"
	if [ -f "$SITE/site/assets/sps.png" ]; then
		cp "$SITE/site/assets/sps.png" "$DATA/custom/public/assets/img/logo.png"
		cp "$SITE/site/assets/sps.png" \
			"$DATA/custom/public/assets/img/apple-touch-icon.png"
	fi
	if [ -f "$SITE/site/assets/favicon.png" ]; then
		cp "$SITE/site/assets/favicon.png" "$DATA/custom/public/assets/img/favicon.png"
	fi
}

write_app_ini() {
	sk=$("$BIN" generate secret SECRET_KEY)
	it=$("$BIN" generate secret INTERNAL_TOKEN)
	jw=$("$BIN" generate secret JWT_SECRET)
	umask 077
	cat >"$CONF" <<EOF
APP_NAME = Splux Git
APP_SLOGAN = official repositories for Splux and SPS
RUN_USER = robert
WORK_PATH = $DATA

[server]
APP_DATA_PATH = $DATA
PROTOCOL = http
DOMAIN = 10.0.0.139
HTTP_ADDR = 0.0.0.0
HTTP_PORT = 3000
ROOT_URL = http://10.0.0.139:3000/
DISABLE_SSH = false
START_SSH_SERVER = true
SSH_DOMAIN = 10.0.0.139
SSH_PORT = 2222
SSH_LISTEN_PORT = 2222
LANDING_PAGE = explore
OFFLINE_MODE = false

[database]
DB_TYPE = sqlite3
PATH = $DATA/forgejo.db

[security]
INSTALL_LOCK = true
SECRET_KEY = $sk
INTERNAL_TOKEN = $it

[oauth2]
JWT_SECRET = $jw

[service]
DISABLE_REGISTRATION = true
REQUIRE_SIGNIN_VIEW = false
ENABLE_NOTIFY_MAIL = false
DEFAULT_KEEP_EMAIL_PRIVATE = true
NO_REPLY_ADDRESS = noreply.splux.robertflexx.dev

[ui]
DEFAULT_THEME = splux
THEMES = splux,forgejo-dark,forgejo-auto,forgejo-light
SHOW_USER_EMAIL = false

[repository]
DEFAULT_BRANCH = main
DEFAULT_PRIVATE = last
ENABLE_PUSH_CREATE_USER = false
ENABLE_PUSH_CREATE_ORG = false

[picture]
DISABLE_GRAVATAR = true
ENABLE_FEDERATED_AVATAR = false

[cors]
ENABLED = true
SCHEME = https
ALLOW_DOMAIN = splux.robertflexx.dev
METHODS = GET,HEAD,OPTIONS
HEADERS = Content-Type,Authorization
MAX_AGE = 10m
ALLOW_CREDENTIALS = false

[other]
SHOW_FOOTER_VERSION = false
SHOW_FOOTER_TEMPLATE_LOAD_TIME = false
SHOW_FOOTER_POWERED_BY = false

[session]
PROVIDER = file

[log]
MODE = file
LEVEL = info
ROOT_PATH = $FORGE/log
EOF
}

install_theme

if [ ! -f "$CONF" ] || ! grep -q '^INSTALL_LOCK = true' "$CONF" 2>/dev/null
then
	write_app_ini
fi

FJ migrate
sh "$FORGE/start.sh"

i=0
while [ "$i" -lt 40 ]
do
	if curl -fsS http://127.0.0.1:3000/api/v1/version >/dev/null 2>&1
	then
		break
	fi
	i=$((i + 1))
	sleep 1
done
curl -fsS http://127.0.0.1:3000/api/v1/version >/dev/null || {
	printf '%s\n' "forgejo did not start on :3000" >&2
	exit 1
}

printf '%s\n' "Splux Git: http://10.0.0.139:3000/" >&2
printf '%s\n' "Create the admin account yourself, then migrate the four GitHub trees from the web UI:" >&2
printf '%s\n' "  $BIN -w $DATA -c $CONF admin user create --username RobertFlexx --email ohf9ck@gmail.com --admin --password 'your-password'" >&2
