#!/bin/sh
# Collect Splux releases and git history into TSV for the news page.
# Fields: epoch iso kind repo url title summary author verified
# Env: CORE EXTRA SPS SITE (git work trees). GH_TOKEN optional via gh.
# Pulls every non-draft SPS release and every commit available from the
# local clones and from the GitHub API. Duplicate URLs keep the last row
# so GitHub author and verified data win over local git.

set -eu

CORE=${CORE:-vendor/core}
EXTRA=${EXTRA:-vendor/extra}
SPS=${SPS:-vendor/sps}
SITE=${SITE:-.}

tab=$(printf '\t')
tmp=$(mktemp -d "${TMPDIR:-/tmp}/splux-news.XXXXXX") || exit 1
out=$tmp/out
trap 'rm -rf "$tmp"' 0 HUP INT TERM
: >"$out"

emit() {
	epoch=$1
	iso=$2
	kind=$3
	repo=$4
	url=$5
	title=$6
	summary=${7-}
	author=${8-}
	verified=${9-}
	title=$(printf '%s' "$title" | tr '\t\r\n' '   ')
	summary=$(printf '%s' "$summary" | tr '\t\r\n' '   ')
	author=$(printf '%s' "$author" | tr '\t\r\n' '   ')
	case $verified in
		yes|no) ;;
		*) verified= ;;
	esac
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$epoch" "$iso" "$kind" "$repo" "$url" "$title" "$summary" \
		"$author" "$verified" >>"$out"
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
	git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
	git -C "$dir" log --format='%ct%x09%cI%x09%H%x09%an%x09%s' 2>/dev/null |
	while IFS=$tab read -r epoch iso hash author subject || [ -n "${epoch-}" ]
	do
		[ -n "${epoch-}" ] || continue
		[ -n "${iso-}" ] || continue
		[ -n "${hash-}" ] || continue
		emit "$epoch" "$iso" commit "$repo" \
			"$baseurl/commit/$hash" "$subject" "" "$author" ""
	done
}

read_commit_tsv() {
	repo=$1
	file=$2
	while IFS=$tab read -r published url title author verified || [ -n "${published-}" ]
	do
		[ -n "${published-}" ] || continue
		[ -n "${url-}" ] || continue
		[ -n "${title-}" ] || title=$url
		epoch=$(epoch_of "$published")
		emit "$epoch" "$published" commit "$repo" "$url" "$title" "" \
			"$author" "$verified"
	done <"$file"
}

git_commits "$SPS" SPS https://github.com/RobertFlexx/SPS
git_commits "$CORE" sps-core https://github.com/RobertFlexx/sps-core
git_commits "$EXTRA" sps-extra https://github.com/RobertFlexx/sps-extra
git_commits "$SITE" splux-site https://github.com/RobertFlexx/splux-site

if command -v gh >/dev/null 2>&1; then
	if gh api --paginate "repos/RobertFlexx/SPS/releases?per_page=100" --jq \
		'.[] | select(.draft == false) | [
			.published_at,
			.html_url,
			((.name // .tag_name) | gsub("[\r\t]"; " ")),
			((.body // "") | gsub("[\r\t]"; " ") | gsub("\n+"; " ") | .[0:900]),
			((.author.login // "") | gsub("[\r\t]"; " "))
		] | @tsv' >"$tmp/rel"
	then
		while IFS=$tab read -r published url name body author || [ -n "${published-}" ]
		do
			[ -n "${published-}" ] || continue
			[ -n "${url-}" ] || continue
			epoch=$(epoch_of "$published")
			emit "$epoch" "$published" release SPS "$url" "$name" "$body" \
				"$author" ""
		done <"$tmp/rel"
	else
		printf '%s\n' "collect-news: GitHub releases request failed" >&2
	fi

	api_commits() {
		path=$1
		label=$2
		if gh api --paginate "repos/${path}/commits?per_page=100" --jq \
			'.[] | [
				.commit.committer.date,
				.html_url,
				((.commit.message // "") | split("\n")[0] | gsub("[\r\t]"; " ")),
				((.author.login // .commit.author.name // "") | gsub("[\r\t]"; " ")),
				(if .commit.verification.verified == true then "yes" else "no" end)
			] | @tsv' >"$tmp/c"
		then
			read_commit_tsv "$label" "$tmp/c"
		else
			printf '%s\n' "collect-news: GitHub commits $path failed" >&2
		fi
	}

	api_commits RobertFlexx/SPS SPS
	api_commits RobertFlexx/sps-core sps-core
	api_commits RobertFlexx/sps-extra sps-extra
	api_commits RobertFlexx/splux-site splux-site
fi

awk -F '\t' '
NF >= 5 && $5 != "" {
	row[$5] = $0
	if (!seen[$5]++) {
		n++
		urls[n] = $5
	}
}
END {
	for (i = 1; i <= n; i++)
		print row[urls[i]]
}' "$out" | LC_ALL=C sort -t "$tab" -k1,1nr
