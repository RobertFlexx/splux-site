#!/bin/sh
# Build the static Splux website from official SPS recipe trees.
# Usage: ./tools/build-site.sh
# Optional: CORE EXTRA SITE_PREFIX OUT

set -eu

cd "$(CDPATH= cd -P "$(dirname "$0")/.." && pwd)" || exit 1

CORE=${CORE:-vendor/core}
EXTRA=${EXTRA:-vendor/extra}
OUT=${OUT:-_site}
SITE_PREFIX=${SITE_PREFIX-}
CORE_GIT=${CORE_GIT:-https://github.com/RobertFlexx/sps-core}
EXTRA_GIT=${EXTRA_GIT:-https://github.com/RobertFlexx/sps-extra}
SPS_GIT=${SPS_GIT:-https://github.com/RobertFlexx/SPS}

if [ ! -d "$CORE" ] || [ ! -d "$EXTRA" ]; then
	mkdir -p vendor
	if [ ! -d "$CORE" ]; then
		printf '%s\n' "cloning sps-core" >&2
		git clone --depth 1 "$CORE_GIT.git" vendor/core
		CORE=vendor/core
	fi
	if [ ! -d "$EXTRA" ]; then
		printf '%s\n' "cloning sps-extra" >&2
		git clone --depth 1 "$EXTRA_GIT.git" vendor/extra
		EXTRA=vendor/extra
	fi
fi

rm -rf "$OUT"
mkdir -p "$OUT/assets" "$OUT/data" "$OUT/download" "$OUT/packages" \
	"$OUT/install" "$OUT/docs" "$OUT/source" "$OUT/news"

cp -a site/assets/. "$OUT/assets/"

# Official SPS logo, three letters. Colors: gray S, yellow P, gray S.
logo_pre='<pre class="logo" aria-label="SPS"><span class="s">  _____     </span><span class="p">_____     </span><span class="s">_____</span>
<span class="s"> /  ___|   </span><span class="p">|  _  \   </span><span class="s">/  ___|</span>
<span class="s"> \ `--.    </span><span class="p">| |_| |   </span><span class="s">\ `--.</span>
<span class="s">  `--. \   </span><span class="p">|  __/     </span><span class="s">`--. \</span>
<span class="s"> /\__/ /   </span><span class="p">| |       </span><span class="s">/\__/ /</span>
<span class="s"> \____/    </span><span class="p">|_|       </span><span class="s">\____/</span></pre>'

write_header() {
	root=$1
	cat <<EOF
<header class="top">
$logo_pre
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
