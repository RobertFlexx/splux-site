#!/bin/sh
# Build the static Splux website from official SPS recipe trees.
# Usage: ./tools/build-site.sh
# Optional: CORE EXTRA SITE_PREFIX OUT

set -eu

cd "$(CDPATH= cd -P "$(dirname "$0")/.." && pwd)" || exit 1

CORE=${CORE:-vendor/core}
EXTRA=${EXTRA:-vendor/extra}
SPS=${SPS:-vendor/sps}
SITE=${SITE:-.}
OUT=${OUT:-_site}
SITE_PREFIX=${SITE_PREFIX-}
CORE_GIT=${CORE_GIT:-https://github.com/RobertFlexx/sps-core}
EXTRA_GIT=${EXTRA_GIT:-https://github.com/RobertFlexx/sps-extra}
SPS_GIT=${SPS_GIT:-https://github.com/RobertFlexx/SPS}
SITE_URL=${SITE_URL:-https://splux.robertflexx.dev}

clone_tree() {
	url=$1
	dest=$2
	depth=${3:-25}
	if [ -d "$dest" ]; then
		return 0
	fi
	mkdir -p vendor
	printf '%s\n' "cloning $url" >&2
	git clone --depth "$depth" "$url" "$dest"
}

if [ ! -d "$CORE" ]; then
	clone_tree "$CORE_GIT.git" vendor/core 25
	CORE=vendor/core
fi
if [ ! -d "$EXTRA" ]; then
	clone_tree "$EXTRA_GIT.git" vendor/extra 25
	EXTRA=vendor/extra
fi
if [ ! -d "$SPS" ]; then
	clone_tree "$SPS_GIT.git" vendor/sps 25
	SPS=vendor/sps
fi

rm -rf "$OUT"
mkdir -p "$OUT/assets" "$OUT/data" "$OUT/download" "$OUT/packages" \
	"$OUT/install" "$OUT/docs" "$OUT/source" "$OUT/news"

cp -a site/assets/. "$OUT/assets/"
if [ -f CNAME ]; then
	cp CNAME "$OUT/CNAME"
fi

write_header() {
	root=$1
	cat <<EOF
<header class="top">
<img class="logo" src="${root}assets/sps.png" width="96" height="96" alt="SPS">
<div class="identity">
<h1>Splux Linux</h1>
<p>source-based Linux using SPS</p>
</div>
</header>
<nav class="row" aria-label="Site">
<a href="${root}">home</a>
<a href="${root}download/">download</a>
<a href="${root}packages/">packages</a>
<a href="${root}install/">install</a>
<a href="${root}docs/">docs</a>
<a href="${root}source/">source</a>
<a href="${root}news/">news</a>
<a class="gh" href="${SPS_GIT}"><img src="${root}assets/github.svg" width="14" height="14" alt=""> SPS</a>
</nav>
EOF
}

write_footer() {
	root=$1
	cat <<EOF
<footer>
<p>Splux Linux</p>
<p><a href="${root}">home</a> · <a href="${root}packages/">packages</a> · <a href="${root}docs/">documentation</a></p>
<p>This site was fully handmade by <a href="https://github.com/RobertFlexx">RobertFlexx</a>.</p>
</footer>
EOF
}

tmp=$(mktemp -d "${TMPDIR:-/tmp}/splux-site.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' 0 HUP INT TERM

tsv=$tmp/packages.tsv
: >"$tsv"
nwarn=0

scan_tree() {
	repo=$1
	rootdir=$2
	github=$3
	find "$rootdir" -name recipe -type f | LC_ALL=C sort | while IFS= read -r rec
	do
		rel=${rec#"$rootdir"/}
		case $rel in
			recipe) pkgpath=. ;;
			*/recipe) pkgpath=${rel%/recipe} ;;
			*) continue ;;
		esac
		if ! awk -f tools/packages.awk \
			-v repo="$repo" \
			-v pkgpath="$pkgpath" \
			-v github="$github" \
			-v outdir="$OUT" \
			"$rec" >>"$tsv"
		then
			printf '%s\n' "warning: skipped $rec" >&2
			nwarn=$((nwarn + 1))
		fi
	done
}

printf '%s\n' "reading recipes" >&2
scan_tree core "$CORE" "$CORE_GIT"
scan_tree extra "$EXTRA" "$EXTRA_GIT"

LC_ALL=C sort -t "$(printf '\t')" -k1,1 -k5,5 "$tsv" >"$tmp/sorted.tsv"
mv "$tmp/sorted.tsv" "$tsv"

npkgs=$(awk 'END { print NR + 0 }' "$tsv")
ncore=$(awk -F '\t' '$5 == "core" { n++ } END { print n + 0 }' "$tsv")
nextra=$(awk -F '\t' '$5 == "extra" { n++ } END { print n + 0 }' "$tsv")
curlver=$(awk -F '\t' '$1 == "curl" { print $2 "-" $3; exit }' "$tsv")
[ -n "$curlver" ] || curlver="8.21.0-1"

awk -F '\t' '
function esc(s) {
	gsub(/&/, "\\&amp;", s)
	gsub(/</, "\\&lt;", s)
	gsub(/>/, "\\&gt;", s)
	gsub(/"/, "\\&quot;", s)
	return s
}
{
	name=$1; ver=$2; rel=$3; repo=$5; cat=$6; desc=$7; path=$8
	search = tolower(name " " desc " " cat " " repo)
	href = "@@ROOT@@packages/" repo "/" path "/"
	printf "<tr data-repo=\"%s\" data-search=\"%s\">", esc(repo), esc(search)
	printf "<td><a class=\"name\" href=\"%s\">%s</a></td>", href, esc(name)
	printf "<td>%s-%s</td>", esc(ver), esc(rel)
	printf "<td>%s</td>", esc(repo)
	printf "<td>%s</td></tr>\n", esc(cat)
}
' "$tsv" >"$tmp/rows.html"

awk -F '\t' '
function jesc(s) {
	gsub(/\\/, "\\\\", s)
	gsub(/"/, "\\\"", s)
	return s
}
BEGIN { print "[" }
{
	if (NR > 1) print ","
	printf "{\"name\":\"%s\",\"version\":\"%s\",\"release\":\"%s\",\"arch\":\"%s\",\"repo\":\"%s\",\"category\":\"%s\",\"description\":\"%s\",\"path\":\"%s\"}", \
		jesc($1), jesc($2), jesc($3), jesc($4), jesc($5), jesc($6), jesc($7), jesc($8)
}
END { print "\n]" }
' "$tsv" >"$OUT/data/packages.json"

tag=unknown
date=unknown
if command -v gh >/dev/null 2>&1; then
	tag=$(gh release view -R RobertFlexx/SPS --json tagName --jq .tagName 2>/dev/null) || tag=unknown
	date=$(gh release view -R RobertFlexx/SPS --json publishedAt --jq .publishedAt 2>/dev/null) || date=unknown
	date=${date%%T*}
fi
if [ "$tag" = unknown ] || [ -z "$tag" ]; then
	tag=latest
	date=see GitHub
fi
generated=$(date -u '+%Y-%m-%d %H:%M UTC' 2>/dev/null || date)

printf '%s\n' "{\"tag\":\"$tag\",\"date\":\"$date\",\"iso_tty\":\"$SPS_GIT/releases/latest/download/sps-live-tty.iso\"}" \
	>"$OUT/data/release.json"

short_sha() {
	git -C "$1" rev-parse --short HEAD 2>/dev/null || printf '%s\n' unknown
}

export CORE EXTRA SPS SITE
if ! sh tools/collect-news.sh >"$tmp/news.tsv"
then
	printf '%s\n' "warning: news collection failed" >&2
	: >"$tmp/news.tsv"
fi
awk -f tools/news.awk -v mode=html "$tmp/news.tsv" >"$tmp/news.html"
awk -f tools/news.awk -v mode=brief "$tmp/news.tsv" >"$tmp/news-brief.html"
generated_iso=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u '+%Y-%m-%dT00:00:00Z')
awk -f tools/news.awk -v mode=atom -v siteurl="$SITE_URL" \
	-v feedupdated="$generated_iso" \
	"$tmp/news.tsv" >"$OUT/news/atom.xml"
cp "$tmp/news.tsv" "$OUT/data/news.tsv"

sps_sha=$(short_sha "$SPS")
core_sha=$(short_sha "$CORE")
extra_sha=$(short_sha "$EXTRA")
site_sha=$(short_sha "$SITE")

cat >"$tmp/news-info.html" <<EOF
<div class="info">
<div class="dl-row"><span class="muted">Latest ISO</span><span><a href="$SPS_GIT/releases/latest">$tag</a> ($date)</span></div>
<div class="dl-row"><span class="muted">SPS</span><span><a href="$SPS_GIT/commit/$sps_sha">$sps_sha</a></span></div>
<div class="dl-row"><span class="muted">sps-core</span><span><a href="$CORE_GIT/commit/$core_sha">$core_sha</a></span></div>
<div class="dl-row"><span class="muted">sps-extra</span><span><a href="$EXTRA_GIT/commit/$extra_sha">$extra_sha</a></span></div>
<div class="dl-row"><span class="muted">Packages</span><span>$npkgs ($ncore core, $nextra extra)</span></div>
<div class="dl-row"><span class="muted">Site build</span><span>$generated ($site_sha)</span></div>
</div>
EOF

subst() {
	src=$1
	dest=$2
	root=$3
	write_header "$root" >"$tmp/header.html"
	write_footer "$root" >"$tmp/footer.html"
	mkdir -p "$(dirname "$dest")"
	awk -f tools/subst.awk \
		-v headerfile="$tmp/header.html" \
		-v footerfile="$tmp/footer.html" \
		-v rowsfile="$tmp/rows.html" \
		-v newsfile="$tmp/news.html" \
		-v brieffile="$tmp/news-brief.html" \
		-v infofile="$tmp/news-info.html" \
		-v root="$root" \
		-v tag="$tag" \
		-v date="$date" \
		-v npkgs="$npkgs" \
		-v ncore="$ncore" \
		-v nextra="$nextra" \
		-v generated="$generated" \
		-v curlver="$curlver" \
		"$src" >"$dest"
}

# Static pages
subst site/index.html "$OUT/index.html" "./"
subst site/download/index.html "$OUT/download/index.html" "../"
subst site/packages/index.html "$OUT/packages/index.html" "../"
subst site/install/index.html "$OUT/install/index.html" "../"
subst site/docs/index.html "$OUT/docs/index.html" "../"
subst site/source/index.html "$OUT/source/index.html" "../"
subst site/news/index.html "$OUT/news/index.html" "../"

# 404 must use an absolute prefix so nested missing URLs still load CSS.
if [ -n "$SITE_PREFIX" ]; then
	abs=${SITE_PREFIX%/}/
else
	abs=/
fi
subst site/404.html "$OUT/404.html" "$abs"

# Detail pages already contain @@HEADER@@ / @@FOOTER@@ and baked asset paths.
# Re-run subst with a per-directory root of "".
# Their <head> links already use ../ prefixes from packages.awk.
find "$OUT/packages" -name index.html | while IFS= read -r page
do
	case $page in
		*/packages/index.html) continue ;;
	esac
	# Count depth below _site for nav ROOT (packages/core/cat/pkg = 4)
	rel=${page#"$OUT"/}
	depth=0
	rest=$rel
	while [ "$rest" != "${rest#*/}" ]
	do
		depth=$((depth + 1))
		rest=${rest#*/}
	done
	root=""
	i=0
	while [ "$i" -lt "$depth" ]
	do
		root="../$root"
		i=$((i + 1))
	done
	write_header "$root" >"$tmp/h2.html"
	write_footer "$root" >"$tmp/f2.html"
	awk -f tools/subst.awk \
		-v headerfile="$tmp/h2.html" \
		-v footerfile="$tmp/f2.html" \
		-v rowsfile="" \
		-v newsfile="" \
		-v brieffile="" \
		-v infofile="" \
		-v root="$root" \
		-v tag="$tag" \
		-v date="$date" \
		-v npkgs="$npkgs" \
		-v ncore="$ncore" \
		-v nextra="$nextra" \
		-v generated="$generated" \
		-v curlver="$curlver" \
		"$page" >"$tmp/page.html"
	mv "$tmp/page.html" "$page"
done

printf '%s\n' "built $OUT ($npkgs packages, $ncore core, $nextra extra, tag $tag)" >&2
