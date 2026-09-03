#!/bin/sh
# Build a static git browser under $OUT/git from local clones.
# Languages follow GitHub Linguist. Authors are GitHub accounts when known.
# Env: OUT CORE EXTRA SPS SITE GIT_HOST SITE_URL

set -eu

cd "$(CDPATH= cd -P "$(dirname "$0")/.." && pwd)" || exit 1

OUT=${OUT:-_site}
CORE=${CORE:-vendor/core}
EXTRA=${EXTRA:-vendor/extra}
SPS=${SPS:-vendor/sps}
SITE=${SITE:-.}
SITE_URL=${SITE_URL:-https://splux.robertflexx.dev}
GIT_HOST=${GIT_HOST:-$SITE_URL/git}
GIT_HOST=${GIT_HOST%/}
AWK=tools/git.awk
LANGAWK=tools/git-lang.awk
MAPFILE=${MAPFILE:-tools/linguist.map}
MAXBLOB=262144
OWNER=RobertFlexx
tab=$(printf '\t')

GIT_KIND=
GIT_REPO=
GIT_USER=
GIT_SHA=
GIT_PATH=

esc() {
	awk -f "$AWK" -v mode=one -v text="$1"
}

# cut -f keeps empty TSV columns. IFS=tab read does not.
tsv_cut() {
	printf '%s\n' "$1" | cut -f "$2"
}

is_git() {
	git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

is_binary_name() {
	case $1 in
		*.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico|*.woff|*.woff2|*.ttf| \
		*.gz|*.xz|*.zst|*.bz2|*.zip|*.tar|*.bin)
			return 0 ;;
	esac
	return 1
}

have_gh() {
	command -v gh >/dev/null 2>&1
}

github_of() {
	case $1 in
		SPS) printf '%s\n' https://github.com/RobertFlexx/SPS ;;
		sps-core) printf '%s\n' https://github.com/RobertFlexx/sps-core ;;
		sps-extra) printf '%s\n' https://github.com/RobertFlexx/sps-extra ;;
		splux-site) printf '%s\n' https://github.com/RobertFlexx/splux-site ;;
		*) printf '%s\n' "https://github.com/RobertFlexx/$1" ;;
	esac
}

desc_of() {
	case $1 in
		SPS) printf '%s\n' 'Source Package System. Installer and live ISO builder.' ;;
		sps-core) printf '%s\n' 'Official base recipe collection.' ;;
		sps-extra) printf '%s\n' 'Official extra recipe collection.' ;;
		splux-site) printf '%s\n' 'This website. Static HTML from the recipe trees.' ;;
		*) printf '%s\n' "$1" ;;
	esac
}

valid_login() {
	case $1 in
		""|-*|*-|*[^A-Za-z0-9-]*) return 1 ;;
	esac
	[ "${#1}" -ge 1 ] && [ "${#1}" -le 39 ]
}

page_begin() {
	_dest=$1
	_title=$2
	_desc=$3
	mkdir -p "$(dirname "$_dest")"
	{
		printf '%s\n' '<!DOCTYPE html>'
		printf '%s\n' '<html lang="en">'
		printf '%s\n' '<head>'
		printf '%s\n' '<meta charset="utf-8">'
		printf '%s\n' '<meta name="viewport" content="width=device-width, initial-scale=1">'
		printf '<title>%s</title>\n' "$(esc "$_title")"
		printf '<meta name="description" content="%s">\n' "$(esc "$_desc")"
		printf '%s\n' '<link rel="icon" href="@@ROOT@@assets/favicon.png" type="image/png">'
		printf '%s\n' '<link rel="stylesheet" href="@@ROOT@@assets/style.css">'
		printf '%s\n' '</head>'
		printf '%s\n' '<body>'
		printf '%s\n' '<a class="skip" href="#main">Skip to content</a>'
		printf '%s\n' '<div class="wrap">'
		printf '%s\n' '@@HEADER@@'
		printf '<main id="main" class="git-page"'
		[ -n "${GIT_KIND-}" ] && printf ' data-kind="%s"' "$(esc "$GIT_KIND")"
		[ -n "${GIT_REPO-}" ] && printf ' data-repo="%s"' "$(esc "$GIT_REPO")"
		[ -n "${GIT_USER-}" ] && printf ' data-user="%s"' "$(esc "$GIT_USER")"
		[ -n "${GIT_SHA-}" ] && printf ' data-sha="%s"' "$(esc "$GIT_SHA")"
		[ -n "${GIT_PATH-}" ] && printf ' data-path="%s"' "$(esc "$GIT_PATH")"
		printf '>\n'
	} >"$_dest"
}

page_end() {
	_dest=$1
	{
		printf '%s\n' '</main>'
		printf '%s\n' '@@FOOTER@@'
		printf '%s\n' '</div>'
		printf '%s\n' '<script src="@@ROOT@@assets/git.js?v=@@LIVE_SIG@@" data-root="@@ROOT@@" data-git="@@GIT_HOST@@"></script>'
		printf '%s\n' '</body></html>'
	} >>"$_dest"
}

write_redirect() {
	dest=$1
	target=$2
	mkdir -p "$(dirname "$dest")"
	{
		printf '%s\n' '<!DOCTYPE html>'
		printf '%s\n' '<html lang="en"><head>'
		printf '%s\n' '<meta charset="utf-8">'
		printf '<meta http-equiv="refresh" content="0;url=%s">\n' "$(esc "$target")"
		printf '<link rel="canonical" href="%s">\n' "$(esc "$target")"
		printf '<title>Redirect</title></head><body>\n'
		printf '<p><a href="%s">Continue</a></p>\n' "$(esc "$target")"
		printf '%s\n' '</body></html>'
	} >"$dest"
}

lookup_lang() {
	_path=$1
	_file=$2
	[ -s "$_file" ] || return 0
	awk -F '\t' -v p="$_path" '$1 == p { print $2 "\t" $4; exit }' "$_file"
}

colorize_langs() {
	awk -F '\t' -v OFS='\t' '
		FNR == NR {
			if ($1 == "lang" && $3 != "")
				c[$3] = $5
			next
		}
		{
			col = ($3 != "") ? $3 : c[$1]
			print $1, $2, col
		}
	' "$MAPFILE" "$1"
}

local_lang_scan() {
	_dir=$1
	_dest=$2
	git -C "$_dir" ls-tree -r -l HEAD | while IFS= read -r line
	do
		set -- $line
		[ "${2-}" = blob ] || continue
		_sz=$4
		_obj=$3
		shift 4
		_path=$*
		[ -n "$_path" ] || continue
		_base=${_path##*/}
		_shebang=
		case $_base in
			*.*|recipe) ;;
			*)
				if ! is_binary_name "$_base"; then
					_shebang=$(git -C "$_dir" cat-file blob "$_obj" | awk 'NR==1 { print; exit }' | tr '\t\r' '  ')
					case $_shebang in
						'#!'*) ;;
						*) _shebang= ;;
					esac
				fi
				;;
		esac
		printf '%s\t%s\t%s\n' "$_sz" "$_path" "$_shebang"
	done >"$_dest"
}

fetch_github_langs() {
	_repo=$1
	_dest=$2
	have_gh || return 1
	gh api "repos/$OWNER/$_repo/languages" --jq \
		'to_entries | sort_by(-.value) | .[] | [.key, (.value|tostring)] | @tsv' \
		>"$_dest" 2>/dev/null && [ -s "$_dest" ]
}

fetch_github_commits() {
	_repo=$1
	_dest=$2
	have_gh || return 1
	gh api --paginate "repos/$OWNER/$_repo/commits?per_page=100" --jq \
		'.[] | [
			.sha,
			(.author.login // .committer.login // ""),
			((.author.avatar_url // .committer.avatar_url // "") | gsub("[\r\t]"; " ")),
			(if .commit.verification.verified == true then "yes" else "no" end)
		] | @tsv' >"$_dest" 2>/dev/null && [ -s "$_dest" ]
}

fetch_github_user() {
	_login=$1
	_dest=$2
	have_gh || return 1
	valid_login "$_login" || return 1
	gh api "users/$_login" --jq \
		'[
			.login,
			((.name // "") | gsub("[\r\t\n]"; " ")),
			((.bio // "") | gsub("[\r\t\n]"; " ")),
			(.avatar_url // ""),
			(.html_url // ""),
			(.public_repos | tostring),
			(.followers | tostring),
			((.company // "") | gsub("[\r\t\n]"; " ")),
			((.location // "") | gsub("[\r\t\n]"; " ")),
			((.blog // "") | gsub("[\r\t\n]"; " "))
		] | @tsv' >"$_dest" 2>/dev/null && [ -s "$_dest" ]
}

who_cell() {
	awk -f "$AWK" -v mode=who \
		-v userpfx="$1" -v login="$2" -v name="$3" \
		-v avatar="$4" -v verified="$5"
}

lang_slug() {
	printf '%s\n' "$1" | tr ' /' '--'
}

# In-repo nav. Links go through @@ROOT@@git/<repo>/ so they work
# without a trailing slash on the current URL.
git_nav() {
	_repo=$1
	_here=$2
	_r="@@ROOT@@git/${_repo}/"
	_gh=$(github_of "$_repo")
	printf '<p class="git-nav">'
	if [ "$_here" = home ]; then
		printf '%s' "$(esc "$_repo")"
	else
		printf '<a href="%s">%s</a>' "$(esc "$_r")" "$(esc "$_repo")"
	fi
	printf ' · '
	if [ "$_here" = log ]; then
		printf 'log'
	else
		printf '<a href="%slog/">log</a>' "$(esc "$_r")"
	fi
	printf ' · '
	if [ "$_here" = files ]; then
		printf 'files'
	else
		printf '<a href="%stree/">files</a>' "$(esc "$_r")"
	fi
	printf ' · '
	if [ "$_here" = refs ]; then
		printf 'refs'
	else
		printf '<a href="%srefs/">refs</a>' "$(esc "$_r")"
	fi
	printf ' · '
	if [ "$_here" = people ]; then
		printf 'people'
	else
		printf '<a href="%speople/">people</a>' "$(esc "$_r")"
	fi
	printf ' · '
	if [ "$_here" = langs ] || [ "$_here" = lang ]; then
		printf 'languages'
	else
		printf '<a href="%slang/">languages</a>' "$(esc "$_r")"
	fi
	printf ' · <a href="%s">GitHub</a>' "$(esc "$_gh")"
	if [ "$_here" = commit ]; then
		printf ' · commit'
	fi
	if [ "$_here" = blob ]; then
		printf ' · file'
	fi
	printf '</p>\n'
}

mkdir -p "$OUT/git" "$OUT/data" "$OUT/git/users"

# Refresh Linguist map when the network allows; keep the committed map otherwise.
if command -v curl >/dev/null 2>&1; then
	yml=$OUT/data/.languages.yml
	if curl -fsSL --max-time 20 \
		-o "$yml" \
		https://raw.githubusercontent.com/github-linguist/linguist/master/lib/linguist/languages.yml
	then
		if awk -f tools/linguist-extract.awk "$yml" >"$OUT/data/.linguist.map" &&
			[ -s "$OUT/data/.linguist.map" ]
		then
			MAPFILE=$OUT/data/.linguist.map
		fi
	fi
	rm -f "$yml"
fi

if [ ! -s "$MAPFILE" ]; then
	printf '%s\n' "git: missing $MAPFILE" >&2
	exit 1
fi

awk -F '\t' '
function jesc(s) {
	gsub(/\\/, "\\\\", s)
	gsub(/"/, "\\\"", s)
	return s
}
BEGIN { printf "{" }
$1 == "lang" && $3 != "" && $5 != "" {
	if (n++) printf ","
	printf "\"%s\":\"%s\"", jesc($3), jesc($5)
}
END { print "}" }
' "$MAPFILE" >"$OUT/data/linguist-colors.json"

index_rows=$OUT/data/git-index.tsv
all_commits=$OUT/data/git-commits.tsv
all_people=$OUT/data/git-people.tsv
: >"$index_rows"
: >"$all_commits"
: >"$all_people"

build_repo() {
	name=$1
	dir=$2
	is_git "$dir" || return 0

	gh=$(github_of "$name")
	repo_desc=$(desc_of "$name")
	head=$(git -C "$dir" rev-parse HEAD)
	short=$(git -C "$dir" rev-parse --short HEAD)
	branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || printf '%s\n' HEAD)
	lastiso=$(git -C "$dir" log -1 --format='%cI')
	ncommits=$(git -C "$dir" rev-list --count HEAD)
	nfiles=$(git -C "$dir" ls-tree -r --name-only HEAD | wc -l)
	nfiles=$(printf '%s' "$nfiles" | tr -d ' ')

	base=$OUT/git/$name
	mkdir -p "$base/log" "$base/refs" "$base/tree" "$base/commit" "$base/blob" \
		"$base/people" "$base/lang"
	userpfx="@@ROOT@@git/users/"
	reporoot="@@ROOT@@git/$name/"

	scan=$base/.scan.tsv
	filelang=$base/.filelang.tsv
	langtmp=$base/.langs.tsv
	local_lang_scan "$dir" "$scan"
	awk -f "$LANGAWK" -v mode=count -v mapfile="$MAPFILE" -v filelang="$filelang" \
		"$scan" >"$base/.langs-local.tsv"
	rm -f "$scan"

	ghl=$base/.langs-gh.tsv
	if fetch_github_langs "$name" "$ghl"; then
		colorize_langs "$ghl" | LC_ALL=C sort -t "$(printf '\t')" -k2,2nr >"$langtmp"
	else
		LC_ALL=C sort -t "$(printf '\t')" -k2,2nr "$base/.langs-local.tsv" >"$langtmp"
	fi
	rm -f "$ghl" "$base/.langs-local.tsv"
	cp "$langtmp" "$OUT/data/git-langs-$name.tsv"

	clog=$base/.commits.tsv
	git -C "$dir" log --format='%H%x09%h%x09%ct%x09%cI%x09%an%x09%s' |
		awk -F '\t' 'BEGIN { OFS="\t" } {
			subj=$6
			for (i = 7; i <= NF; i++) subj = subj " " $i
			gsub(/\t/, " ", subj)
			print $1, $2, $3, $4, subj, $5
		}' >"$base/.commits-local.tsv"
	ghc=$base/.commits-gh.tsv
	if fetch_github_commits "$name" "$ghc"; then
		awk -F '\t' -v OFS='\t' '
			FNR == NR { login[$1]=$2; av[$1]=$3; ver[$1]=$4; next }
			{ print $1, $2, $3, $4, $5, $6, login[$1], av[$1], ver[$1] }
		' "$ghc" "$base/.commits-local.tsv" >"$clog"
	else
		awk -F '\t' -v OFS='\t' '{ print $0, "", "", "" }' \
			"$base/.commits-local.tsv" >"$clog"
	fi
	rm -f "$ghc" "$base/.commits-local.tsv"

	awk -F '\t' -v OFS='\t' -v repo="$name" '{
		print repo, $1, $2, $3, $4, $5, $6, $7, $8, $9
	}' "$clog" >>"$all_commits"

	awk -F '\t' -v OFS='\t' '{
		login=$7
		name=$6
		key = (login != "") ? login : name
		if (key == "") next
		c[key]++
		if (login != "")
			haslogin[key]=login
		if ($8 != "" && !(key in avatar))
			avatar[key]=$8
		if (name != "" && !(key in author))
			author[key]=name
		epoch=$3+0
		if (!(key in last) || epoch >= last[key]) {
			last[key]=epoch
			iso[key]=$4
			subj[key]=$5
			sha[key]=$1
		}
	}
	END {
		for (k in c)
			print (k in haslogin) ? haslogin[k] : "", avatar[k], c[k], \
				(k in author) ? author[k] : k, iso[k], subj[k], sha[k]
	}' "$clog" | LC_ALL=C sort -t "$(printf '\t')" -k3,3nr >"$base/.people.tsv"
	if [ -s "$base/.people.tsv" ]; then
		awk -F '\t' -v OFS='\t' '$1 != "" { print $1, $2, $3 }' \
			"$base/.people.tsv" >>"$all_people"
	fi

	# Languages with file counts for the bar and the language index.
	awk -F '\t' -v OFS='\t' -v fl="$filelang" '
		BEGIN {
			while ((getline < fl) > 0) {
				path=$1
				name=$2
				col=$4
				sz=$5+0
				group=($6 != "") ? $6 : $2
				if (name != "") {
					key = name SUBSEP path
					if (!(key in seen)) {
						seen[key]=1
						nf[name]++
						fsz[name]+=sz
					}
					if (col != "" && !(name in color))
						color[name]=col
				}
				if (group != "" && group != name) {
					key = group SUBSEP path
					if (!(key in seen)) {
						seen[key]=1
						nf[group]++
						fsz[group]+=sz
					}
				}
			}
			close(fl)
		}
		{
			gh[$1]=$2+0
			if ($3 != "")
				color[$1]=$3
			bar[$1]=1
		}
		END {
			for (k in nf)
				all[k]=1
			for (k in bar)
				all[k]=1
			n=0
			for (k in all) {
				n++
				names[n]=k
			}
			for (i = 1; i <= n; i++) {
				for (j = i + 1; j <= n; j++) {
					bi = (names[i] in gh) ? gh[names[i]] : fsz[names[i]]+0
					bj = (names[j] in gh) ? gh[names[j]] : fsz[names[j]]+0
					if (bj > bi) {
						t=names[i]; names[i]=names[j]; names[j]=t
					}
				}
			}
			for (i = 1; i <= n; i++) {
				k=names[i]
				print k, gh[k]+0, color[k], nf[k]+0, fsz[k]+0
			}
		}
	' "$langtmp" >"$base/.lang-index.tsv"
	awk -F '\t' -v OFS='\t' '$2 + 0 > 0 { print $1, $2, $3, $4 }' \
		"$base/.lang-index.tsv" >"$base/.langs-bar.tsv"
	if [ -s "$base/.langs-bar.tsv" ]; then
		mv "$base/.langs-bar.tsv" "$langtmp"
	else
		rm -f "$base/.langs-bar.tsv"
	fi

	GIT_KIND=repo
	GIT_REPO=$name
	GIT_USER=
	GIT_SHA=
	GIT_PATH=

	page_begin "$base/index.html" "$name - Splux Git" "$repo_desc"
	{
		printf '<h2>%s</h2>\n' "$(esc "$name")"
		printf '%s\n' '<hr class="rule">'
		printf '<p>%s</p>\n' "$(esc "$repo_desc")"
		git_nav "$name" home
		printf '%s\n' '<p class="live-note" id="git-live" hidden>Showing newer commits from GitHub.</p>'
		printf '%s\n' '<div class="info" id="git-info">'
		printf '<div class="dl-row"><span class="muted">HEAD</span><span id="git-head"><a href="commit/%s/"><code>%s</code></a> (%s)</span></div>\n' \
			"$(esc "$head")" "$(esc "$short")" "$(esc "$branch")"
		printf '<div class="dl-row"><span class="muted">Commits</span><span id="git-ncommits">%s</span></div>\n' \
			"$(esc "$ncommits")"
		printf '<div class="dl-row"><span class="muted">Files</span><span>%s</span></div>\n' \
			"$(esc "$nfiles")"
		printf '<div class="dl-row"><span class="muted">Clone</span><span><code>git clone %s.git</code></span></div>\n' \
			"$(esc "$gh")"
		printf '%s\n' '</div>'
		if [ -s "$langtmp" ]; then
			printf '%s\n' '<h3>Languages</h3>'
			printf '%s\n' '<div id="git-langs">'
			awk -f "$AWK" -v mode=langs -v langpfx="${reporoot}lang/" "$langtmp"
			printf '%s\n' '</div>'
		else
			printf '%s\n' '<div id="git-langs"></div>'
		fi
		if [ -s "$base/.people.tsv" ]; then
			printf '%s\n' '<h3>People</h3>'
			awk -f "$AWK" -v mode=people -v userpfx="$userpfx" "$base/.people.tsv"
			printf '<p><a href="%speople/">All contributors</a></p>\n' "$(esc "$reporoot")"
		fi
		printf '%s\n' '<h3>Recent commits</h3>'
		printf '%s\n' '<div id="git-recent">'
		awk -f "$AWK" -v mode=commits -v commitpfx="${reporoot}commit/" \
			-v userpfx="$userpfx" -v limit=20 "$clog"
		printf '%s\n' '</div>'
		printf '%s\n' '<p><a href="log/">Full log</a></p>'
		if git -C "$dir" cat-file -e HEAD:README.md 2>/dev/null; then
			printf '%s\n' '<h3>README.md</h3>'
			git -C "$dir" show HEAD:README.md | awk -f "$AWK" -v mode=pre
		elif git -C "$dir" cat-file -e HEAD:README 2>/dev/null; then
			printf '%s\n' '<h3>README</h3>'
			git -C "$dir" show HEAD:README | awk -f "$AWK" -v mode=pre
		fi
	} >>"$base/index.html"
	page_end "$base/index.html"

	GIT_KIND=log
	page_begin "$base/log/index.html" "Log - $name - Splux Git" "Commit log for $name"
	{
		git_nav "$name" log
		printf '<h2>Log</h2>\n'
		printf '%s\n' '<hr class="rule">'
		printf '%s\n' '<p class="live-note" id="git-live" hidden>Showing newer commits from GitHub.</p>'
		printf '%s\n' '<div id="git-log">'
		awk -f "$AWK" -v mode=commits -v commitpfx="${reporoot}commit/" \
			-v userpfx="$userpfx" "$clog"
		printf '%s\n' '</div>'
	} >>"$base/log/index.html"
	page_end "$base/log/index.html"

	GIT_KIND=refs
	page_begin "$base/refs/index.html" "Refs - $name - Splux Git" "Branches and tags for $name"
	{
		git_nav "$name" refs
		printf '<h2>Refs</h2>\n'
		printf '%s\n' '<hr class="rule">'
		printf '%s\n' '<h3>Branches</h3>'
		printf '%s\n' '<ul class="plain">'
		git -C "$dir" for-each-ref --format='%(objectname) %(refname:short)' refs/heads |
		while IFS= read -r line
		do
			[ -n "$line" ] || continue
			h=${line%% *}
			r=${line#* }
			printf '<li><a href="../commit/%s/">%s</a> <code>%s</code></li>\n' \
				"$(esc "$h")" "$(esc "$r")" "$(esc "${h%"${h#???????}"}")"
		done
		printf '%s\n' '</ul>'
		printf '%s\n' '<h3>Tags</h3>'
		printf '%s\n' '<ul class="plain">'
		git -C "$dir" for-each-ref --format='%(objectname) %(refname:short)' refs/tags |
		while IFS= read -r line
		do
			[ -n "$line" ] || continue
			h=${line%% *}
			r=${line#* }
			c=$(git -C "$dir" rev-parse "$r^{commit}" 2>/dev/null || printf '%s\n' "$h")
			printf '<li><a href="../commit/%s/">%s</a></li>\n' \
				"$(esc "$c")" "$(esc "$r")"
		done
		printf '%s\n' '</ul>'
	} >>"$base/refs/index.html"
	page_end "$base/refs/index.html"

	while IFS= read -r _line || [ -n "${_line-}" ]
	do
		[ -n "${_line-}" ] || continue
		hash=$(tsv_cut "$_line" 1)
		shortc=$(tsv_cut "$_line" 2)
		iso=$(tsv_cut "$_line" 4)
		subject=$(tsv_cut "$_line" 5)
		author=$(tsv_cut "$_line" 6)
		login=$(tsv_cut "$_line" 7)
		avatar=$(tsv_cut "$_line" 8)
		verified=$(tsv_cut "$_line" 9)
		[ -n "$hash" ] || continue
		cdir=$base/commit/$hash
		mkdir -p "$cdir"
		GIT_KIND=commit
		GIT_SHA=$hash
		GIT_PATH=
		page_begin "$cdir/index.html" "$shortc - $name - Splux Git" "$subject"
		{
			git_nav "$name" commit
			printf '<h2><code>%s</code></h2>\n' "$(esc "$shortc")"
			printf '%s\n' '<hr class="rule">'
			printf '<p>%s</p>\n' "$(esc "$subject")"
			printf '%s\n' '<div class="info">'
			printf '<div class="dl-row"><span class="muted">Author</span><span>%s</span></div>\n' \
				"$(who_cell "$userpfx" "$login" "$author" "$avatar" "$verified")"
			printf '<div class="dl-row"><span class="muted">Date</span><span><time datetime="%s">%s</time></span></div>\n' \
				"$(esc "$iso")" "$(esc "$iso")"
			printf '<div class="dl-row"><span class="muted">Commit</span><span><code>%s</code></span></div>\n' \
				"$(esc "$hash")"
			printf '<div class="dl-row"><span class="muted">GitHub</span><span><a href="%s/commit/%s">mirror</a></span></div>\n' \
				"$(esc "$gh")" "$(esc "$hash")"
			printf '%s\n' '</div>'
			printf '%s\n' '<h3>Parents</h3>'
			printf '%s\n' '<ul class="plain">'
			git -C "$dir" rev-list --parents -n 1 "$hash" | {
				read -r self rest || rest=
				for p in $rest
				do
					ps=$(git -C "$dir" rev-parse --short "$p")
					printf '<li><a href="../%s/"><code>%s</code></a></li>\n' \
						"$(esc "$p")" "$(esc "$ps")"
				done
			}
			printf '%s\n' '</ul>'
			printf '%s\n' '<h3>Stat</h3>'
			git -C "$dir" show --stat --format= "$hash" | awk -f "$AWK" -v mode=pre
			printf '%s\n' '<h3>Diff</h3>'
			git -C "$dir" show --format= --color=never "$hash" |
				dd bs=1024 count=300 2>/dev/null |
				awk -f "$AWK" -v mode=pre
		} >>"$cdir/index.html"
		page_end "$cdir/index.html"
		if [ -n "$shortc" ] && [ "$shortc" != "$hash" ]; then
			write_redirect "$base/commit/$shortc/index.html" "../$hash/"
		fi
	done <"$clog"

	write_tree() {
		treepath=${1-}
		GIT_KIND=tree
		GIT_SHA=
		GIT_PATH=$treepath
		if [ -n "$treepath" ]; then
			tdest=$base/tree/$treepath/index.html
			title="$treepath - $name - Splux Git"
		else
			tdest=$base/tree/index.html
			title="Files - $name - Splux Git"
		fi
		if [ -z "$treepath" ]; then
			up_repo="../"
			blobpfx="../blob/"
			treepfx="./"
		else
			depth=1
			rest=$treepath
			while [ "$rest" != "${rest#*/}" ]
			do
				depth=$((depth + 1))
				rest=${rest#*/}
			done
			up=""
			j=0
			while [ "$j" -le "$depth" ]
			do
				up="../$up"
				j=$((j + 1))
			done
			up_repo=$up
			blobpfx=$up"blob/"
			treepfx="./"
		fi
		page_begin "$tdest" "$title" "HEAD tree for $name"
		{
			git_nav "$name" files
			if [ -n "$treepath" ]; then
				printf '<h2>%s</h2>\n' "$(esc "$treepath")"
			else
				printf '%s\n' '<h2>Files</h2>'
			fi
			printf '%s\n' '<hr class="rule">'
			if [ -n "$treepath" ]; then
				printf '<p><a href="../">../</a></p>\n'
			fi
			printf '%s\n' '<p><label for="git-filter">Filter</label> <input id="git-filter" type="search" placeholder="file"></p>'
			ent=$base/.entries.tsv
			: >"$ent"
			if [ -n "$treepath" ]; then
				git -C "$dir" ls-tree -l "HEAD:$treepath"
			else
				git -C "$dir" ls-tree -l HEAD
			fi | while IFS= read -r line
			do
				set -- $line
				[ $# -ge 5 ] || continue
				kind=$2
				sz=$4
				shift 4
				path=$*
				basepath=${path##*/}
				[ -n "$basepath" ] || continue
				if [ "$kind" = tree ]; then
					printf 'dir\t\t%s\t%s\t\n' "$basepath/" "$treepfx$basepath/"
				elif [ "$kind" = blob ]; then
					if [ -n "$treepath" ]; then
						fullpath=$treepath/$basepath
					else
						fullpath=$basepath
					fi
					fl=$(lookup_lang "$fullpath" "$filelang")
					flang=${fl%%$tab*}
					printf 'file\t%s\t%s\t%s\t%s\n' "$sz" "$basepath" "$blobpfx$fullpath/" "$flang"
				fi
			done >"$ent"
			if [ -s "$ent" ]; then
				awk -f "$AWK" -v mode=entries -v langpfx="${reporoot}lang/" "$ent"
			else
				printf '%s\n' '<p class="muted">empty directory</p>'
			fi
		} >>"$tdest"
		page_end "$tdest"
	}

	write_tree ""
	git -C "$dir" ls-tree -r -d --name-only HEAD | while IFS= read -r d
	do
		[ -n "$d" ] || continue
		write_tree "$d"
	done

	git -C "$dir" ls-tree -r -l HEAD | while IFS= read -r line
	do
		set -- $line
		[ "$2" = blob ] || continue
		sz=$4
		obj=$3
		shift 4
		path=$*
		[ -n "$path" ] || continue
		bdest=$base/blob/$path/index.html
		GIT_KIND=blob
		GIT_SHA=
		GIT_PATH=$path
		page_begin "$bdest" "$path - $name - Splux Git" "$path at HEAD"
		fl=$(lookup_lang "$path" "$filelang")
		flang=${fl%%$tab*}
		fcolor=${fl#*$tab}
		[ "$fcolor" = "$fl" ] && fcolor=
		{
			git_nav "$name" blob
			printf '<h2>%s</h2>\n' "$(esc "$path")"
			printf '%s\n' '<hr class="rule">'
			if [ -n "$flang" ]; then
				printf '<p class="lang-badge"><a href="%slang/%s/"><span class="lang-dot" style="background:%s"></span> %s</a></p>\n' \
					"$(esc "$reporoot")" "$(esc "$(lang_slug "$flang")")" \
					"$(esc "${fcolor:-#888888}")" "$(esc "$flang")"
			fi
			printf '<p class="muted">%s bytes at <a href="%scommit/%s/">%s</a> · <a href="%s/blob/main/%s">GitHub</a></p>\n' \
				"$(esc "$sz")" "$(esc "$reporoot")" "$(esc "$head")" "$(esc "$short")" \
				"$(esc "$gh")" "$(esc "$path")"
			szn=$(printf '%s' "$sz" | tr -d ' ')
			case $szn in
				''|*[!0-9]*) szn=0 ;;
			esac
			if is_binary_name "$path"; then
				printf '%s\n' '<p>Binary file. Clone the repository or open the GitHub mirror.</p>'
			elif [ "$szn" -gt "$MAXBLOB" ]; then
				printf '%s\n' '<p>File is too large to embed here. Clone the repository or open the GitHub mirror.</p>'
			else
				git -C "$dir" cat-file blob "$obj" | awk -f "$AWK" -v mode=pre
			fi
		} >>"$bdest"
		page_end "$bdest"
	done

	GIT_KIND=people
	GIT_SHA=
	GIT_PATH=
	page_begin "$base/people/index.html" "People - $name - Splux Git" \
		"Commit authors in $name"
	{
		git_nav "$name" people
		printf '%s\n' '<h2>People</h2>'
		printf '%s\n' '<hr class="rule">'
		printf '<p>Everyone who authored a commit in %s. GitHub accounts link to their profile. Authors without a GitHub login are listed by git name. <a href="@@ROOT@@git/users/">All people</a></p>\n' \
			"$(esc "$name")"
		printf '%s\n' '<p class="live-note" id="git-live" hidden>Updated from GitHub.</p>'
		printf '%s\n' '<p><label for="git-filter">Filter</label> <input id="git-filter" type="search" placeholder="person"></p>'
		if [ -s "$base/.people.tsv" ]; then
			awk -f "$AWK" -v mode=peoplelist -v userpfx="$userpfx" \
				-v commitpfx="${reporoot}commit/" "$base/.people.tsv"
		else
			printf '%s\n' '<table class="pkgs git-people" id="git-people-table"><thead><tr><th>Person</th><th>Commits</th><th>Last commit</th><th>When</th></tr></thead><tbody></tbody></table>'
		fi
	} >>"$base/people/index.html"
	page_end "$base/people/index.html"

	GIT_KIND=langs
	GIT_PATH=
	page_begin "$base/lang/index.html" "Languages - $name - Splux Git" \
		"Languages in $name"
	{
		git_nav "$name" langs
		printf '%s\n' '<h2>Languages</h2>'
		printf '%s\n' '<hr class="rule">'
		printf '%s\n' '<p>Click a language to see how many files use it.</p>'
		printf '%s\n' '<p><label for="git-filter">Filter</label> <input id="git-filter" type="search" placeholder="language"></p>'
		if [ -s "$base/.lang-index.tsv" ]; then
			awk -f "$AWK" -v mode=langindex -v langpfx="${reporoot}lang/" \
				"$base/.lang-index.tsv"
		else
			printf '%s\n' '<p class="muted">No languages recorded.</p>'
		fi
	} >>"$base/lang/index.html"
	page_end "$base/lang/index.html"

	if [ -s "$base/.lang-index.tsv" ]; then
		while IFS= read -r _lline || [ -n "${_lline-}" ]
		do
			[ -n "${_lline-}" ] || continue
			langname=$(tsv_cut "$_lline" 1)
			nlangfiles=$(tsv_cut "$_lline" 4)
			langbytes=$(tsv_cut "$_lline" 5)
			[ -n "$langname" ] || continue
			lslug=$(lang_slug "$langname")
			ldest=$base/lang/$lslug/index.html
			GIT_KIND=lang
			GIT_PATH=$langname
			page_begin "$ldest" "$langname - $name - Splux Git" \
				"$langname files in $name"
			{
				git_nav "$name" lang
				printf '<h2>%s</h2>\n' "$(esc "$langname")"
				printf '%s\n' '<hr class="rule">'
				printf '<p>%s files' "$(esc "${nlangfiles:-0}")"
				if [ -n "$langbytes" ] && [ "$langbytes" != 0 ]; then
					printf ', %s bytes' "$(esc "$langbytes")"
				fi
				printf ' · <a href="%slang/">all languages</a></p>\n' \
					"$(esc "$reporoot")"
				printf '%s\n' '<p><label for="git-filter">Filter</label> <input id="git-filter" type="search" placeholder="file"></p>'
				lf=$base/.lang-files.tsv
				awk -F '\t' -v OFS='\t' -v lang="$langname" \
					-v blobpfx="${reporoot}blob/" '
					$2 == lang || $6 == lang {
						print "file", $5, $1, blobpfx $1 "/", $2
					}
				' "$filelang" | LC_ALL=C sort -t "$(printf '\t')" -k3,3 >"$lf"
				if [ -s "$lf" ]; then
					awk -f "$AWK" -v mode=entries -v showlang=no "$lf"
				else
					printf '%s\n' '<p class="muted">No files listed for this language.</p>'
				fi
			} >>"$ldest"
			page_end "$ldest"
			rm -f "$lf"
		done <"$base/.lang-index.tsv"
	fi

	day=${lastiso%%T*}
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$name" "$repo_desc" "$short" "$head" "$ncommits" "$nfiles" "$day" "$gh" \
		>>"$index_rows"

	rm -f "$langtmp" "$clog" "$base/.entries.tsv" "$base/.people.tsv" \
		"$filelang" "$base/.lang-index.tsv"
	printf '%s\n' "git: $name ($ncommits commits, $nfiles files)" >&2
}

build_repo SPS "$SPS"
build_repo sps-core "$CORE"
build_repo sps-extra "$EXTRA"
build_repo splux-site "$SITE"

# People across trees
users_raw=$OUT/data/.users-raw.tsv
awk -F '\t' -v OFS='\t' '
	$1 == "" { next }
	{
		login=$1
		av=$2
		c[login] += $3 + 0
		if (av != "" && !(login in avatar))
			avatar[login]=av
	}
	END {
		for (l in c)
			print l, avatar[l], c[l]
	}
' "$all_people" | LC_ALL=C sort -t "$(printf '\t')" -k3,3nr >"$users_raw"

users_full=$OUT/data/git-users.tsv
: >"$users_full"
if [ -s "$users_raw" ]; then
	while IFS="$(printf '\t')" read -r login avatar n || [ -n "${login-}" ]
	do
		[ -n "${login-}" ] || continue
		valid_login "$login" || continue
		uf=$OUT/data/.user-$login.tsv
		if fetch_github_user "$login" "$uf"; then
			awk -F '\t' -v OFS='\t' -v n="$n" -v av="$avatar" '{
				if ($4 == "" && av != "") $4 = av
				print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, n
			}' "$uf" >>"$users_full"
		else
			printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
				"$login" "" "" "$avatar" "https://github.com/$login" \
				"" "" "" "" "" "$n" >>"$users_full"
		fi
		rm -f "$uf"
	done <"$users_raw"
fi
rm -f "$users_raw"

GIT_KIND=users
GIT_REPO=
GIT_USER=
GIT_SHA=
GIT_PATH=
page_begin "$OUT/git/users/index.html" "People - Splux Git" "GitHub accounts that pushed to the official Splux trees."
{
	printf '%s\n' '<p class="git-nav"><a href="../">git</a> · people</p>'
	printf '%s\n' '<h2>People</h2>'
	printf '%s\n' '<hr class="rule">'
	printf '%s\n' '<p>Accounts that authored commits in SPS, sps-core, sps-extra, and this site. Avatars and names come from GitHub. Open someone to see their profile and their commits here.</p>'
	printf '%s\n' '<p class="live-note" id="git-live" hidden>Updated from GitHub.</p>'
	if [ -s "$users_full" ]; then
		awk -F '\t' -v OFS='\t' '{ print $1, $4, $11 }' "$users_full" |
			awk -f "$AWK" -v mode=people -v userpfx="@@ROOT@@git/users/"
	else
		printf '%s\n' '<p class="muted">No GitHub accounts recorded for these commits.</p>'
	fi
} >>"$OUT/git/users/index.html"
page_end "$OUT/git/users/index.html"

tab=$(printf '\t')
if [ -s "$users_full" ]; then
	while IFS= read -r _line || [ -n "${_line-}" ]
	do
		[ -n "${_line-}" ] || continue
		login=$(tsv_cut "$_line" 1)
		name=$(tsv_cut "$_line" 2)
		bio=$(tsv_cut "$_line" 3)
		avatar=$(tsv_cut "$_line" 4)
		htmlurl=$(tsv_cut "$_line" 5)
		prepos=$(tsv_cut "$_line" 6)
		followers=$(tsv_cut "$_line" 7)
		company=$(tsv_cut "$_line" 8)
		location=$(tsv_cut "$_line" 9)
		blog=$(tsv_cut "$_line" 10)
		n=$(tsv_cut "$_line" 11)
		[ -n "$login" ] || continue
		udest=$OUT/git/users/$login/index.html
		GIT_KIND=user
		GIT_USER=$login
		page_begin "$udest" "$login - Splux Git" "GitHub account $login"
		{
			printf '%s\n' '<p class="git-nav"><a href="../../">git</a> · <a href="../">people</a></p>'
			printf '%s\n' '<div class="profile" id="git-profile">'
			if [ -n "$avatar" ]; then
				printf '<img class="avatar profile-avatar" src="%s" width="80" height="80" alt="">\n' \
					"$(esc "$avatar")"
			fi
			printf '%s\n' '<div class="profile-body">'
			printf '<h2>%s</h2>\n' "$(esc "$login")"
			if [ -n "$name" ] && [ "$name" != "$login" ]; then
				printf '<p class="profile-name">%s</p>\n' "$(esc "$name")"
			fi
			if [ -n "$bio" ]; then
				printf '<p>%s</p>\n' "$(esc "$bio")"
			fi
			printf '%s\n' '<div class="info">'
			if [ -n "$htmlurl" ]; then
				printf '<div class="dl-row"><span class="muted">GitHub</span><span><a href="%s">%s</a></span></div>\n' \
					"$(esc "$htmlurl")" "$(esc "$login")"
			fi
			if [ -n "$company" ]; then
				printf '<div class="dl-row"><span class="muted">Company</span><span>%s</span></div>\n' \
					"$(esc "$company")"
			fi
			if [ -n "$location" ]; then
				printf '<div class="dl-row"><span class="muted">Location</span><span>%s</span></div>\n' \
					"$(esc "$location")"
			fi
			if [ -n "$blog" ]; then
				printf '<div class="dl-row"><span class="muted">URL</span><span><a href="%s">%s</a></span></div>\n' \
					"$(esc "$blog")" "$(esc "$blog")"
			fi
			if [ -n "$prepos" ]; then
				printf '<div class="dl-row"><span class="muted">Public repos</span><span>%s</span></div>\n' \
					"$(esc "$prepos")"
			fi
			if [ -n "$followers" ]; then
				printf '<div class="dl-row"><span class="muted">Followers</span><span>%s</span></div>\n' \
					"$(esc "$followers")"
			fi
			if [ -n "$n" ]; then
				printf '<div class="dl-row"><span class="muted">Commits here</span><span>%s</span></div>\n' \
					"$(esc "$n")"
			fi
			printf '%s\n' '</div>'
			printf '%s\n' '</div></div>'
			printf '%s\n' '<h3>Commits in Splux trees</h3>'
			printf '%s\n' '<div id="git-user-log">'
			awk -F '\t' -v OFS='\t' -v login="$login" '
				$8 == login {
					print $2, $3, $4, $5, $6, $7, $8, $9, $10, $1
				}
			' "$all_commits" |
				awk -f "$AWK" -v mode=commits -v repopfx="@@ROOT@@git/" \
					-v userpfx="@@ROOT@@git/users/"
			printf '%s\n' '</div>'
		} >>"$udest"
		page_end "$udest"
	done <"$users_full"
fi

GIT_KIND=index
GIT_REPO=
GIT_USER=
GIT_SHA=
GIT_PATH=
page_begin "$OUT/git/index.html" "Git - Splux Linux" "Always-updating browse of the official Splux git trees."
{
	printf '%s\n' '<h2>Git</h2>'
	printf '%s\n' '<hr class="rule">'
	printf '%s\n' '<p>This is a live HTML mirror of the official trees. Languages match GitHub Linguist. Each commit shows the GitHub account that uploaded it, with their avatar. Open <a href="users/">people</a> for profiles. Pages rebuild with the handbook; the browser also asks GitHub for anything newer. There is no git server here. Clone the GitHub URLs.</p>'
	printf '%s\n' '<p class="git-nav"><a href="users/">people</a></p>'
	printf '%s\n' '<p class="live-note" id="git-live" hidden>Updated from GitHub.</p>'
	printf '%s\n' '<p><label for="git-filter">Filter</label> <input id="git-filter" type="search" placeholder="repository"></p>'
	printf '%s\n' '<table class="pkgs" id="git-repos">'
	printf '%s\n' '<thead><tr><th>Repository</th><th>Description</th><th>HEAD</th><th>Commits</th><th>Updated</th></tr></thead>'
	printf '%s\n' '<tbody>'
	if [ -s "$index_rows" ]; then
		while IFS="$tab" read -r name desc short head ncommits nfiles day gh || [ -n "${name-}" ]
		do
			[ -n "${name-}" ] || continue
			printf '<tr data-repo="%s" data-search="%s %s">' \
				"$(esc "$name")" "$(esc "$name")" "$(esc "$desc")"
			printf '<td><a class="name" href="%s/">%s</a></td>' "$(esc "$name")" "$(esc "$name")"
			printf '<td>%s</td>' "$(esc "$desc")"
			printf '<td><a href="%s/commit/%s/"><code>%s</code></a></td>' \
				"$(esc "$name")" "$(esc "$head")" "$(esc "$short")"
			printf '<td>%s</td>' "$(esc "$ncommits")"
			printf '<td>%s</td>' "$(esc "$day")"
			printf '</tr>\n'
		done <"$index_rows"
	fi
	printf '%s\n' '</tbody></table>'
	if [ -s "$users_full" ]; then
		printf '%s\n' '<h3>People</h3>'
		awk -F '\t' -v OFS='\t' '{ print $1, $4, $11 }' "$users_full" |
			awk -f "$AWK" -v mode=people -v userpfx="@@ROOT@@git/users/"
	fi
	printf '%s\n' '<h3>Clone</h3>'
	printf '%s\n' '<pre class="block">git clone https://github.com/RobertFlexx/SPS.git'
	printf '%s\n' 'git clone https://github.com/RobertFlexx/sps-core.git'
	printf '%s\n' 'git clone https://github.com/RobertFlexx/sps-extra.git'
	printf '%s\n' 'git clone https://github.com/RobertFlexx/splux-site.git</pre>'
	printf '%s\n' '<p class="note">Live ISO files stay on GitHub Releases. Recipe browse also lives under <a href="@@ROOT@@packages/">packages</a>.</p>'
} >>"$OUT/git/index.html"
page_end "$OUT/git/index.html"

# JSON summaries
awk -F '\t' '
function jesc(s) {
	gsub(/\\/, "\\\\", s)
	gsub(/"/, "\\\"", s)
	return s
}
BEGIN { print "[" }
{
	if (NR > 1) print ","
	printf "{\"name\":\"%s\",\"description\":\"%s\",\"head\":\"%s\",\"full\":\"%s\",\"commits\":%s,\"files\":%s,\"updated\":\"%s\",\"github\":\"%s\"}", \
		jesc($1), jesc($2), jesc($3), jesc($4), $5 + 0, $6 + 0, jesc($7), jesc($8)
}
END { print "\n]" }
' "$index_rows" >"$OUT/data/git.json"

awk -F '\t' '
function jesc(s) {
	gsub(/\\/, "\\\\", s)
	gsub(/"/, "\\\"", s)
	return s
}
BEGIN { print "[" }
{
	if (NR > 1) print ","
	printf "{\"login\":\"%s\",\"name\":\"%s\",\"bio\":\"%s\",\"avatar\":\"%s\",\"github\":\"%s\",\"public_repos\":%s,\"followers\":%s,\"company\":\"%s\",\"location\":\"%s\",\"blog\":\"%s\",\"commits\":%s}", \
		jesc($1), jesc($2), jesc($3), jesc($4), jesc($5), $6 + 0, $7 + 0, jesc($8), jesc($9), jesc($10), $11 + 0
}
END { print "\n]" }
' "$users_full" >"$OUT/data/git-users.json"

rm -f "$OUT/data/.linguist.map" "$all_people"
# Keep git-commits.tsv and git-langs-*.tsv for the live script if needed;
# commits TSV can be large. Drop it from the Pages artifact.
rm -f "$all_commits"

printf '%s\n' "git: wrote $OUT/git" >&2
