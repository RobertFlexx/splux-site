#!/bin/sh
# Collect Splux releases and git history into TSV for the news page.
# Fields: epoch iso kind repo url title summary
# Env: CORE EXTRA SPS SITE (git work trees). GH_TOKEN optional via gh.

set -eu

CORE=${CORE:-vendor/core}
EXTRA=${EXTRA:-vendor/extra}
SPS=${SPS:-vendor/sps}
SITE=${SITE:-.}

tab=$(printf '\t')
out=$(mktemp "${TMPDIR:-/tmp}/splux-news.XXXXXX") || exit 1
trap 'rm -f "$out" "$rel"' 0 HUP INT TERM
rel=

emit() {
	epoch=$1
	iso=$2
	kind=$3
	repo=$4
	url=$5
	title=$6
	summary=${7-}
	title=$(printf '%s' "$title" | tr '\t\r\n' '   ')
	summary=$(printf '%s' "$summary" | tr '\t\r\n' '   ')
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$epoch" "$iso" "$kind" "$repo" "$url" "$title" "$summary" >>"$out"
}

epoch_of() {
	iso=$1
	day=${iso%%T*}
	if date -u -d "$iso" +%s >/dev/null 2>&1; then
		date -u -d "$iso" +%s
		return 0
	fi
	awk -v d="$day" 'BEGIN {
		n = split(d, a, "-")
		if (n != 3) { print 0; exit }
		print mktime(a[1] " " a[2] " " a[3] " 12 0 0") + 0
	}'
}

git_commits() {
	dir=$1
	repo=$2
	baseurl=$3
	n=${4:-12}
	git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
	git -C "$dir" log -n "$n" --format='%ct%x09%cI%x09%H%x09%s' 2>/dev/null |
	while IFS=$tab read -r epoch iso hash subject || [ -n "${epoch-}" ]
	do
		[ -n "${epoch-}" ] || continue
		[ -n "${iso-}" ] || continue
		[ -n "${hash-}" ] || continue
		emit "$epoch" "$iso" commit "$repo" \
			"$baseurl/commit/$hash" "$subject" ""
	done
}

git_commits "$SPS" SPS https://github.com/RobertFlexx/SPS 15
git_commits "$CORE" sps-core https://github.com/RobertFlexx/sps-core 15
git_commits "$EXTRA" sps-extra https://github.com/RobertFlexx/sps-extra 15
git_commits "$SITE" splux-site https://github.com/RobertFlexx/splux-site 8

if command -v gh >/dev/null 2>&1; then
	rel=$(mktemp "${TMPDIR:-/tmp}/splux-rel.XXXXXX") || exit 1
	if gh api "repos/RobertFlexx/SPS/releases?per_page=25" --jq \
		'.[] | select(.draft == false) | [
			.published_at,
			.html_url,
			(.name // .tag_name),
			((.body // "") | gsub("[\r\t]"; " ") | gsub("\n+"; " ") | .[0:900])
		] | @tsv' >"$rel" 2>/dev/null
	then
		while IFS=$tab read -r published url name body || [ -n "${published-}" ]
		do
			[ -n "${published-}" ] || continue
			[ -n "${url-}" ] || continue
			epoch=$(epoch_of "$published")
			emit "$epoch" "$published" release SPS "$url" "$name" "$body"
		done <"$rel"
	fi
fi

LC_ALL=C sort -t "$tab" -k1,1nr "$out"
