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
GIT_HOST=${GIT_HOST:-https://git.splux.robertflexx.dev}

clone_tree() {
	url=$1
	dest=$2
	if [ -d "$dest" ]; then
		return 0
	fi
	mkdir -p vendor
	printf '%s\n' "cloning $url" >&2
	git clone "$url" "$dest"
}

if [ ! -d "$CORE" ]; then
	clone_tree "$CORE_GIT.git" vendor/core
	CORE=vendor/core
fi
if [ ! -d "$EXTRA" ]; then
	clone_tree "$EXTRA_GIT.git" vendor/extra
	EXTRA=vendor/extra
fi
if [ ! -d "$SPS" ]; then
	clone_tree "$SPS_GIT.git" vendor/sps
	SPS=vendor/sps
fi

rm -rf "$OUT"
mkdir -p "$OUT/assets" "$OUT/data" "$OUT/download" "$OUT/packages" \
	"$OUT/install" "$OUT/docs" "$OUT/docs/images" "$OUT/docs/sps" \
	"$OUT/docs/first-boot" "$OUT/source" "$OUT/news" "$OUT/git"

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
<a href="${root}git/">git</a>
<a href="${root}source/">source</a>
<a href="${root}news/">news</a>
</nav>
EOF
}

write_footer() {
	root=$1
	cat <<EOF
<footer>
<p>Splux Linux</p>
<p><a href="${root}">home</a> · <a href="${root}packages/">packages</a> · <a href="${root}git/">git</a> · <a href="${root}docs/">documentation</a></p>
<p>This site was fully handmade by <a href="${GIT_HOST}/RobertFlexx">RobertFlexx</a>.</p>
</footer>
EOF
}

write_docs_nav() {
	root=$1
	cur=$2
	printf '%s\n' '<nav class="docs-side" aria-label="Handbook">'
	printf '%s\n' '<p class="docs-kicker">Handbook</p>'
	printf '%s\n' '<ul class="docs-toc">'
	set -- \
		overview "${root}docs/" "Overview" \
		images "${root}docs/images/" "Live images" \
		install "${root}install/" "Install" \
		sps "${root}docs/sps/" "SPS tools" \
		firstboot "${root}docs/first-boot/" "After first boot" \
		git "${root}git/" "Git"
	while [ "$#" -ge 3 ]
	do
		if [ "$cur" = "$1" ]; then
			printf '<li><a href="%s" aria-current="page">%s</a></li>\n' \
				"$2" "$3"
		else
			printf '<li><a href="%s">%s</a></li>\n' "$2" "$3"
		fi
		shift 3
	done
	printf '%s\n' '</ul>'
	printf '%s\n' '</nav>'
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
	mirror=${4-}
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
			-v mirror="$mirror" \
			-v outdir="$OUT" \
			"$rec" >>"$tsv"
		then
			printf '%s\n' "warning: skipped $rec" >&2
			nwarn=$((nwarn + 1))
		fi
	done
}

printf '%s\n' "reading recipes" >&2
scan_tree core "$CORE" "$GIT_HOST/RobertFlexx/sps-core" "https://github.com/RobertFlexx/sps-core"
scan_tree extra "$EXTRA" "$GIT_HOST/RobertFlexx/sps-extra" "https://github.com/RobertFlexx/sps-extra"

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

# GitHub's "latest" flag can lag. Pick the highest live-YYYY-MM-DD[-N]
# tag by numeric suffix. String sort ranks -9 above -15.
pick_live_release() {
	gh api "repos/RobertFlexx/SPS/releases?per_page=100" --jq '
		def rank:
			capture("^live-(?<y>[0-9]+)-(?<m>[0-9]+)-(?<d>[0-9]+)(?:-(?<n>[0-9]+))?$")
			| [(.y|tonumber), (.m|tonumber), (.d|tonumber), ((.n // "0")|tonumber)];
		[.[] | select(.draft == false) | select(.tag_name | test("^live-[0-9]{4}-[0-9]{2}-[0-9]{2}(-[0-9]+)?$"))]
		| if length == 0 then empty else max_by(.tag_name | rank) end
		| [.tag_name, .published_at] | @tsv
	' 2>/dev/null
}

tag=unknown
date=unknown
published=
if command -v gh >/dev/null 2>&1; then
	picked=$(pick_live_release || true)
	if [ -n "$picked" ]; then
		tag=${picked%%	*}
		published=${picked#*	}
		date=${published%%T*}
	fi
	if [ "$tag" = unknown ] || [ -z "$tag" ]; then
		tag=$(gh release view -R RobertFlexx/SPS --json tagName --jq .tagName 2>/dev/null) || tag=unknown
		published=$(gh release view -R RobertFlexx/SPS --json publishedAt --jq .publishedAt 2>/dev/null) || published=
		date=${published%%T*}
	fi
fi
if [ "$tag" = unknown ] || [ -z "$tag" ]; then
	tag=latest
	date="see GitHub"
	published=
fi
generated=$(date -u '+%Y-%m-%d %H:%M UTC' 2>/dev/null || date)

iso_base=$SPS_GIT/releases/latest/download
notes_url=$SPS_GIT/releases/latest
case $tag in
	latest|unknown) ;;
	*)
		iso_base=$SPS_GIT/releases/download/$tag
		notes_url=$SPS_GIT/releases/tag/$tag
		;;
esac
printf '%s\n' "{\"tag\":\"$tag\",\"date\":\"$date\",\"published_at\":\"$published\",\"iso_tty\":\"$iso_base/sps-live-tty.iso\",\"iso_slim\":\"$iso_base/sps-live-tty-slim.iso\",\"iso_plasma\":\"$iso_base/sps-live-plasma.iso\",\"sha256sums\":\"$iso_base/SHA256SUMS\"}" \
	>"$OUT/data/release.json"

short_sha() {
	git -C "$1" rev-parse --short HEAD 2>/dev/null || printf '%s\n' unknown
}

export CORE EXTRA SPS SITE GIT_HOST
if ! sh tools/collect-news.sh >"$tmp/news.tsv"
then
	printf '%s\n' "warning: news collection failed" >&2
	: >"$tmp/news.tsv"
fi
awk -f tools/news.awk -v mode=brief "$tmp/news.tsv" >"$tmp/news-brief.html"
generated_iso=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u '+%Y-%m-%dT00:00:00Z')
awk -f tools/news.awk -v mode=atom -v siteurl="$SITE_URL" \
	-v feedupdated="$generated_iso" \
	"$tmp/news.tsv" >"$OUT/news/atom.xml"
awk -f tools/news.awk -v mode=json "$tmp/news.tsv" >"$OUT/data/news.json"
cp "$tmp/news.tsv" "$OUT/data/news.tsv"

news_per=20
nnews=$(awk 'END { print NR + 0 }' "$tmp/news.tsv")
if [ "$nnews" -lt 1 ]; then
	news_pages=1
else
	news_pages=$(( (nnews + news_per - 1) / news_per ))
fi
: >"$tmp/pager.html"
: >"$tmp/news.html"
pagetitle=

sps_sha=$(short_sha "$SPS")
core_sha=$(short_sha "$CORE")
extra_sha=$(short_sha "$EXTRA")
site_sha=$(short_sha "$SITE")
livesig=${site_sha}-$(date -u '+%Y%m%d%H%M%S' 2>/dev/null || date +%Y%m%d%H%M%S)

cat >"$tmp/news-info.html" <<EOF
<div class="info">
<div class="dl-row"><span class="muted">Latest ISO</span><span id="live-iso"><a href="$notes_url">$tag</a> ($date)</span></div>
<div class="dl-row"><span class="muted">SPS</span><span id="live-sps"><a href="$GIT_HOST/RobertFlexx/SPS/commit/$sps_sha">$sps_sha</a></span></div>
<div class="dl-row"><span class="muted">sps-core</span><span id="live-core"><a href="$GIT_HOST/RobertFlexx/sps-core/commit/$core_sha">$core_sha</a></span></div>
<div class="dl-row"><span class="muted">sps-extra</span><span id="live-extra"><a href="$GIT_HOST/RobertFlexx/sps-extra/commit/$extra_sha">$extra_sha</a></span></div>
<div class="dl-row"><span class="muted">Packages</span><span>$npkgs ($ncore core, $nextra extra)</span></div>
<div class="dl-row"><span class="muted">Site build</span><span>$generated ($site_sha)</span></div>
</div>
EOF

subst() {
	src=$1
	dest=$2
	root=$3
	docscurrent=${4-}
	write_header "$root" >"$tmp/header.html"
	write_footer "$root" >"$tmp/footer.html"
	write_docs_nav "$root" "$docscurrent" >"$tmp/docsnav.html"
	mkdir -p "$(dirname "$dest")"
	awk -f tools/subst.awk \
		-v headerfile="$tmp/header.html" \
		-v footerfile="$tmp/footer.html" \
		-v docsnavfile="$tmp/docsnav.html" \
		-v rowsfile="$tmp/rows.html" \
		-v newsfile="$tmp/news.html" \
		-v brieffile="$tmp/news-brief.html" \
		-v infofile="$tmp/news-info.html" \
		-v pagerfile="$tmp/pager.html" \
		-v pagetitle="$pagetitle" \
		-v root="$root" \
		-v tag="$tag" \
		-v date="$date" \
		-v npkgs="$npkgs" \
		-v ncore="$ncore" \
		-v nextra="$nextra" \
		-v generated="$generated" \
		-v livesig="$livesig" \
		-v curlver="$curlver" \
		-v githost="$GIT_HOST" \
		"$src" >"$dest"
}

# Static pages
subst site/index.html "$OUT/index.html" "./"
subst site/download/index.html "$OUT/download/index.html" "../"
subst site/packages/index.html "$OUT/packages/index.html" "../"
subst site/install/index.html "$OUT/install/index.html" "../" install
subst site/docs/index.html "$OUT/docs/index.html" "../" overview
subst site/docs/images/index.html "$OUT/docs/images/index.html" "../../" images
subst site/docs/sps/index.html "$OUT/docs/sps/index.html" "../../" sps
subst site/docs/first-boot/index.html "$OUT/docs/first-boot/index.html" "../../" firstboot
subst site/source/index.html "$OUT/source/index.html" "../"
subst site/git/index.html "$OUT/git/index.html" "../"

awk -f tools/news.awk -v mode=html -v page=1 -v per="$news_per" \
	"$tmp/news.tsv" >"$tmp/news.html"
awk -f tools/news.awk -v mode=pager -v page=1 -v pages="$news_pages" \
	-v per="$news_per" -v nest=0 "$tmp/news.tsv" >"$tmp/pager.html"
pagetitle=
subst site/news/index.html "$OUT/news/index.html" "../"
news_p=2
while [ "$news_p" -le "$news_pages" ]
do
	awk -f tools/news.awk -v mode=html -v page="$news_p" -v per="$news_per" \
		"$tmp/news.tsv" >"$tmp/news.html"
	awk -f tools/news.awk -v mode=pager -v page="$news_p" -v pages="$news_pages" \
		-v per="$news_per" -v nest=1 "$tmp/news.tsv" >"$tmp/pager.html"
	pagetitle=" page $news_p"
	subst site/news/index.html "$OUT/news/$news_p/index.html" "../../"
	news_p=$((news_p + 1))
done
pagetitle=
: >"$tmp/pager.html"

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
		-v livesig="$livesig" \
		-v curlver="$curlver" \
		-v githost="$GIT_HOST" \
		"$page" >"$tmp/page.html"
	mv "$tmp/page.html" "$page"
done

printf '%s\n' "built $OUT ($npkgs packages, $ncore core, $nextra extra, tag $tag)" >&2
