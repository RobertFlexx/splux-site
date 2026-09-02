#!/bin/sh
# Build a static git browser under $OUT/git from local clones.
# No forge and no git-http-backend. Clone URLs are GitHub.
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
MAXBLOB=262144

esc() {
	awk -f "$AWK" -v mode=one -v text="$1"
}

is_git() {
	git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

lang_of() {
	path=$1
	base=${path##*/}
	case $path in
		lib/setup/sv/*)
			printf '%s\n' Shell
			return
			;;
	esac
	case $base in
		recipe) printf '%s\n' Recipe; return ;;
		run) printf '%s\n' Shell; return ;;
		Makefile|makefile|GNUmakefile) printf '%s\n' Make; return ;;
		LICENSE|COPYING|COPYRIGHT) printf '%s\n' Text; return ;;
		.gitignore|.gitattributes|.gitmodules) printf '%s\n' Git; return ;;
		CNAME) printf '%s\n' Text; return ;;
	esac
	case $path in
		*.sh) printf '%s\n' Shell ;;
		*.awk) printf '%s\n' AWK ;;
		*.c|*.h|*.in) printf '%s\n' C ;;
		*.md) printf '%s\n' Markdown ;;
		*.html) printf '%s\n' HTML ;;
		*.css) printf '%s\n' CSS ;;
		*.js) printf '%s\n' JavaScript ;;
		*.json) printf '%s\n' JSON ;;
		*.yml|*.yaml) printf '%s\n' YAML ;;
		*.py) printf '%s\n' Python ;;
		*.scm) printf '%s\n' Scheme ;;
		*.service) printf '%s\n' systemd ;;
		*.1|*.5|*.8) printf '%s\n' Manual ;;
		*.svg) printf '%s\n' SVG ;;
		*.xml) printf '%s\n' XML ;;
		*.txt|*.conf|*.ini|*.cfg) printf '%s\n' Text ;;
		*.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico|*.woff|*.woff2|*.ttf)
			printf '%s\n' Binary ;;
		*.gz|*.xz|*.zst|*.bz2|*.zip|*.tar)
			printf '%s\n' Binary ;;
		*) printf '%s\n' Other ;;
	esac
}

is_binary_name() {
	case $1 in
		*.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico|*.woff|*.woff2|*.ttf| \
		*.gz|*.xz|*.zst|*.bz2|*.zip|*.tar|*.bin)
			return 0 ;;
	esac
	return 1
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
		printf '%s\n' '<main id="main">'
	} >"$_dest"
}

page_end() {
	_dest=$1
	{
		printf '%s\n' '</main>'
		printf '%s\n' '@@FOOTER@@'
		printf '%s\n' '</div>'
		if [ "${2-}" = "gitjs" ]; then
			printf '%s\n' '<script src="@@ROOT@@assets/git.js?v=@@LIVE_SIG@@"></script>'
		fi
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

mkdir -p "$OUT/git" "$OUT/data"

index_rows=$OUT/data/git-index.tsv
: >"$index_rows"

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
	mkdir -p "$base/log" "$base/refs" "$base/tree" "$base/commit" "$base/blob"

	# Language counts by blob size at HEAD.
	langtmp=$base/.langs.tsv
	: >"$langtmp"
	git -C "$dir" ls-tree -r -l HEAD | while IFS= read -r line
	do
		# 100644 blob HASH SIZE PATH
		set -- $line
		mode=$1
		kind=$2
		obj=$3
		sz=$4
		shift 4
		path=$*
		[ "$kind" = blob ] || continue
		[ -n "$path" ] || continue
		lang=$(lang_of "$path")
		printf '%s\t%s\n' "$lang" "$sz"
	done | awk -F '\t' '
		{ b[$1] += $2 + 0 }
		END {
			for (k in b)
				print k "\t" b[k]
		}
	' | LC_ALL=C sort -t "$(printf '\t')" -k2,2nr >"$langtmp"

	# Commits
	clog=$base/.commits.tsv
	git -C "$dir" log --format='%H%x09%h%x09%ct%x09%cI%x09%an%x09%s' |
		awk -F '\t' 'BEGIN { OFS="\t" } {
			subj=$6
			for (i = 7; i <= NF; i++) subj = subj " " $i
			gsub(/\t/, " ", subj)
			print $1, $2, $3, $4, subj, $5
		}' >"$clog"

	# Repo home
	page_begin "$base/index.html" "$name - Splux Git" "$repo_desc"
	{
		printf '<h2>%s</h2>\n' "$(esc "$name")"
		printf '%s\n' '<hr class="rule">'
		printf '<p>%s</p>\n' "$(esc "$repo_desc")"
		printf '%s\n' '<p class="git-nav">'
		printf '<a href="log/">log</a> · <a href="tree/">files</a> · <a href="refs/">refs</a> · '
		printf '<a href="%s">GitHub mirror</a>\n' "$(esc "$gh")"
		printf '%s\n' '</p>'
		printf '%s\n' '<div class="info">'
		printf '<div class="dl-row"><span class="muted">HEAD</span><span><a href="commit/%s/"><code>%s</code></a> (%s)</span></div>\n' \
			"$(esc "$head")" "$(esc "$short")" "$(esc "$branch")"
		printf '<div class="dl-row"><span class="muted">Commits</span><span>%s</span></div>\n' \
			"$(esc "$ncommits")"
		printf '<div class="dl-row"><span class="muted">Files</span><span>%s</span></div>\n' \
			"$(esc "$nfiles")"
		printf '<div class="dl-row"><span class="muted">Clone</span><span><code>git clone %s.git</code></span></div>\n' \
			"$(esc "$gh")"
		printf '%s\n' '</div>'
		if [ -s "$langtmp" ]; then
			printf '%s\n' '<h3>Languages</h3>'
			awk -f "$AWK" -v mode=langs "$langtmp"
		fi
		printf '%s\n' '<h3>Recent commits</h3>'
		awk -f "$AWK" -v mode=commits -v commitpfx="commit/" -v limit=20 "$clog"
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

	# Full log
	page_begin "$base/log/index.html" "Log - $name - Splux Git" "Commit log for $name"
	{
		printf '<p class="git-nav"><a href="../">%s</a> · log</p>\n' "$(esc "$name")"
		printf '<h2>Log</h2>\n'
		printf '%s\n' '<hr class="rule">'
		awk -f "$AWK" -v mode=commits -v commitpfx="../commit/" "$clog"
	} >>"$base/log/index.html"
	page_end "$base/log/index.html"

	# Refs
	page_begin "$base/refs/index.html" "Refs - $name - Splux Git" "Branches and tags for $name"
	{
		printf '<p class="git-nav"><a href="../">%s</a> · refs</p>\n' "$(esc "$name")"
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
		ntags=0
		git -C "$dir" for-each-ref --format='%(objectname) %(refname:short)' refs/tags |
		while IFS= read -r line
		do
			[ -n "$line" ] || continue
			h=${line%% *}
			r=${line#* }
			# Peel annotated tags to the commit when possible.
			c=$(git -C "$dir" rev-parse "$r^{commit}" 2>/dev/null || printf '%s\n' "$h")
			printf '<li><a href="../commit/%s/">%s</a></li>\n' \
				"$(esc "$c")" "$(esc "$r")"
			ntags=1
		done
		if [ "$ntags" = 0 ]; then
			:
		fi
		printf '%s\n' '</ul>'
	} >>"$base/refs/index.html"
	page_end "$base/refs/index.html"

	# Commits
	while IFS="$(printf '\t')" read -r hash shortc epoch iso subject author || [ -n "${hash-}" ]
	do
		[ -n "${hash-}" ] || continue
		cdir=$base/commit/$hash
		mkdir -p "$cdir"
		page_begin "$cdir/index.html" "$shortc - $name - Splux Git" "$subject"
		{
			printf '<p class="git-nav"><a href="../../">%s</a> · <a href="../../log/">log</a> · commit</p>\n' \
				"$(esc "$name")"
			printf '<h2><code>%s</code></h2>\n' "$(esc "$shortc")"
			printf '%s\n' '<hr class="rule">'
			printf '<p>%s</p>\n' "$(esc "$subject")"
			printf '%s\n' '<div class="info">'
			printf '<div class="dl-row"><span class="muted">Author</span><span>%s</span></div>\n' \
				"$(esc "$author")"
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
			# Truncate huge diffs so the Pages artifact stays small.
			git -C "$dir" show --format= --color=never "$hash" |
				dd bs=1024 count=300 2>/dev/null |
				awk -f "$AWK" -v mode=pre
		} >>"$cdir/index.html"
		page_end "$cdir/index.html"
		if [ -n "$shortc" ] && [ "$shortc" != "$hash" ]; then
			write_redirect "$base/commit/$shortc/index.html" "../$hash/"
		fi
	done <"$clog"

	# Trees and blobs at HEAD
	write_tree() {
		treepath=${1-}
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
			printf '<p class="git-nav"><a href="%s">%s</a> · files</p>\n' \
				"$(esc "$up_repo")" "$(esc "$name")"
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
					printf 'dir\t\t%s\t%s\n' "$basepath/" "$treepfx$basepath/"
				elif [ "$kind" = blob ]; then
					if [ -n "$treepath" ]; then
						fullpath=$treepath/$basepath
					else
						fullpath=$basepath
					fi
					printf 'file\t%s\t%s\t%s\n' "$sz" "$basepath" "$blobpfx$fullpath/"
				fi
			done >"$ent"
			if [ -s "$ent" ]; then
				awk -f "$AWK" -v mode=entries "$ent"
			else
				printf '%s\n' '<p class="muted">empty directory</p>'
			fi
		} >>"$tdest"
		page_end "$tdest" gitjs
	}

	write_tree ""
	# Every directory that contains a blob.
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
		page_begin "$bdest" "$path - $name - Splux Git" "$path at HEAD"
		parent=${path%/*}
		# depth of blob/path/... 
		depth=1
		rest=$path
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
		# blob/a/b -> up is ../../../ (blob + a + b) = depth+1, plus we started le depth so depth+1. Good.
		{
			if [ "$parent" = "$path" ]; then
				dirhref="${up}tree/"
			else
				dirhref="${up}tree/${parent}/"
			fi
			printf '<p class="git-nav"><a href="%s">%s</a> · <a href="%s">directory</a></p>\n' \
				"$(esc "$up")" "$(esc "$name")" "$(esc "$dirhref")"
			printf '<h2>%s</h2>\n' "$(esc "$path")"
			printf '%s\n' '<hr class="rule">'
			printf '<p class="muted">%s bytes at <a href="%scommit/%s/">%s</a> · <a href="%s/blob/main/%s">GitHub</a></p>\n' \
				"$(esc "$sz")" "$(esc "$up")" "$(esc "$head")" "$(esc "$short")" \
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

	day=${lastiso%%T*}
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$name" "$repo_desc" "$short" "$head" "$ncommits" "$nfiles" "$day" "$gh" \
		>>"$index_rows"

	rm -f "$langtmp" "$clog" "$base/.entries.tsv"
	printf '%s\n' "git: $name ($ncommits commits, $nfiles files)" >&2
}

build_repo SPS "$SPS"
build_repo sps-core "$CORE"
build_repo sps-extra "$EXTRA"
build_repo splux-site "$SITE"

# Index
page_begin "$OUT/git/index.html" "Git - Splux Linux" "Static browse of the official Splux git trees."
{
	printf '%s\n' '<h2>Git</h2>'
	printf '%s\n' '<hr class="rule">'
	printf '%s\n' '<p>This is a static browse of the official trees, rebuilt with the handbook. There is no git server here: no accounts, no pull requests, and no <code>git clone</code> from this host. Clone the GitHub mirrors. The commits, files, and language counts on these pages are the same history.</p>'
	printf '%s\n' '<p><label for="git-filter">Filter</label> <input id="git-filter" type="search" placeholder="repository"></p>'
	printf '%s\n' '<table class="pkgs" id="git-repos">'
	printf '%s\n' '<thead><tr><th>Repository</th><th>Description</th><th>HEAD</th><th>Commits</th><th>Updated</th></tr></thead>'
	printf '%s\n' '<tbody>'
	if [ -s "$index_rows" ]; then
		while IFS="$(printf '\t')" read -r name desc short head ncommits nfiles day gh || [ -n "${name-}" ]
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
	printf '%s\n' '<h3>Clone</h3>'
	printf '%s\n' '<pre class="block">git clone https://github.com/RobertFlexx/SPS.git'
	printf '%s\n' 'git clone https://github.com/RobertFlexx/sps-core.git'
	printf '%s\n' 'git clone https://github.com/RobertFlexx/sps-extra.git'
	printf '%s\n' 'git clone https://github.com/RobertFlexx/splux-site.git</pre>'
	printf '%s\n' '<p class="note">Live ISO files stay on GitHub Releases. Recipe browse also lives under <a href="@@ROOT@@packages/">packages</a>.</p>'
} >>"$OUT/git/index.html"
page_end "$OUT/git/index.html" gitjs

# JSON summary
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

printf '%s\n' "git: wrote $OUT/git" >&2
