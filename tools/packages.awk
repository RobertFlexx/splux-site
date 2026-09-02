# Read one SPS recipe. Print one TSV record. Optionally write a detail page.
# Fields: name version release arch repo category description path
#         depend builddep optional conflict source

function trim(s) {
	sub(/^[ \t]+/, "", s)
	sub(/[ \t]+$/, "", s)
	return s
}

function html_esc(s) {
	gsub(/&/, "\\&amp;", s)
	gsub(/</, "\\&lt;", s)
	gsub(/>/, "\\&gt;", s)
	gsub(/"/, "\\&quot;", s)
	gsub(/\t/, " ", s)
	return s
}

function json_esc(s) {
	gsub(/\\/, "\\\\", s)
	gsub(/"/, "\\\"", s)
	gsub(/\t/, "\\t", s)
	gsub(/\n/, "\\n", s)
	gsub(/\r/, "\\r", s)
	return s
}

function append_dep(key, value,    n, f, i, item) {
	value = trim(value)
	gsub(/[ \t,]+/, " ", value)
	n = split(value, f, /[ ]+/)
	for (i = 1; i <= n; i++) {
		item = trim(f[i])
		if (item == "") continue
		if (val[key] != "") val[key] = val[key] ", "
		val[key] = val[key] item
	}
}

function expand(s,    pass, prev) {
	for (pass = 1; pass <= 8; pass++) {
		prev = s
		gsub(/\$\{name\}/, val["name"], s)
		gsub(/\$\{version\}/, val["version"], s)
		gsub(/\$\{release\}/, val["release"], s)
		gsub(/\$\{arch\}/, val["arch"], s)
		if (s == prev) break
	}
	return s
}

function warn(msg) {
	printf "packages.awk: %s:%d: %s\n", FILENAME, FNR, msg > "/dev/stderr"
}

function process(line,    key, value, sep) {
	line = trim(line)
	if (line == "" || line ~ /^#/) return
	sep = match(line, /[ \t]/)
	if (!sep) {
		warn("expected key value")
		failed = 1
		return
	}
	key = substr(line, 1, RSTART - 1)
	value = trim(substr(line, RSTART + RLENGTH))
	if (value == "") {
		warn("empty value for " key)
		failed = 1
		return
	}
	if (key == "name" || key == "version" || key == "release" ||
	    key == "arch" || key == "description") {
		if (seen[key]) {
			warn("duplicate " key)
			failed = 1
			return
		}
		seen[key] = 1
		val[key] = value
	} else if (key == "depend" || key == "builddep" || key == "optional" ||
		   key == "conflict") {
		append_dep(key, value)
	} else if (key == "source") {
		if (source == "") source = value
	} else if (key == "hash" || key == "install" || key == "prepare" ||
		   key == "configure" || key == "build") {
		# indexing only
	} else {
		warn("unknown field " key)
	}
}

function list_html(page, label, items,    n, f, i) {
	if (items == "") return
	print "<p>" html_esc(label) "</p>" > page
	print "<ul class=\"plain\">" > page
	n = split(items, f, ", ")
	for (i = 1; i <= n; i++) {
		print "<li>" html_esc(f[i]) "</li>" > page
	}
	print "</ul>" > page
}

function write_page(    dir, ncomp, i, prefix, parts, cat, page, gh_dir) {
	ncomp = split(pkgpath, parts, "/")
	prefix = ""
	# packages/repo/ + path components
	for (i = 0; i < ncomp + 2; i++) prefix = prefix "../"
	cat = parts[1]
	gh_dir = pkgpath
	page = outdir "/packages/" repo "/" pkgpath "/index.html"
	system("mkdir -p \"" outdir "/packages/" repo "/" pkgpath "\"")
	print "<!DOCTYPE html>" > page
	print "<html lang=\"en\">" > page
	print "<head>" > page
	print "<meta charset=\"utf-8\">" > page
	print "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">" > page
	print "<title>" html_esc(val["name"]) " - Splux Linux</title>" > page
	print "<link rel=\"icon\" href=\"" prefix "assets/favicon.png\" type=\"image/png\">" > page
	print "<link rel=\"stylesheet\" href=\"" prefix "assets/style.css\">" > page
	print "</head><body>" > page
	print "<div class=\"wrap\">" > page
	# header/footer filled later by build-site via markers
	print "@@HEADER@@" > page
	print "<main id=\"main\">" > page
	print "<h2>" html_esc(val["name"]) " " html_esc(val["version"]) "-" html_esc(val["release"]) "</h2>" > page
	print "<hr class=\"rule\">" > page
	print "<dl class=\"meta\">" > page
	print "<dt>description</dt><dd>" html_esc(val["description"]) "</dd>" > page
	print "<dt>repository</dt><dd>" html_esc(repo) "</dd>" > page
	print "<dt>category</dt><dd>" html_esc(cat) "</dd>" > page
	print "<dt>architecture</dt><dd>" html_esc(val["arch"]) "</dd>" > page
	if (source != "")
		print "<dt>source</dt><dd><a href=\"" html_esc(expand(source)) "\">" html_esc(expand(source)) "</a></dd>" > page
	print "</dl>" > page
	list_html(page, "dependencies", val["depend"])
	list_html(page, "build dependencies", val["builddep"])
	list_html(page, "optional dependencies", val["optional"])
	list_html(page, "conflicts", val["conflict"])
	print "<p>recipe<br>" > page
	if (github ~ /github\.com/) {
		print "<a href=\"" github "/blob/main/" gh_dir "/recipe\">view recipe</a><br>" > page
		print "<a href=\"" github "/tree/main/" gh_dir "\">repository directory</a><br>" > page
		print "<a href=\"" github "/commits/main/" gh_dir "\">history</a>" > page
	} else {
		print "<a href=\"" github "/src/branch/main/" gh_dir "/recipe\">view recipe</a><br>" > page
		print "<a href=\"" github "/src/branch/main/" gh_dir "\">repository directory</a><br>" > page
		print "<a href=\"" github "/commits/branch/main/" gh_dir "\">history</a>" > page
	}
	if (mirror != "") {
		print "<br>" > page
		print "<a href=\"" mirror "/blob/main/" gh_dir "/recipe\">GitHub mirror</a>" > page
	}
	print "</p>" > page
	print "</main>" > page
	print "@@FOOTER@@" > page
	print "</div></body></html>" > page
	close(page)
}

BEGIN {
	if (repo == "") repo = "unknown"
	if (github == "") github = "https://git.splux.robertflexx.dev/RobertFlexx/sps-core"
	if (pkgpath == "") pkgpath = "unknown"
}

{
	sub(/\r$/, "", $0)
	if (continuing)
		logical = logical $0
	else
		logical = $0
	if (logical ~ /\\[ \t]*$/) {
		sub(/\\[ \t]*$/, "", logical)
		logical = logical " "
		continuing = 1
		next
	}
	continuing = 0
	process(logical)
	logical = ""
}

END {
	if (continuing) {
		warn("unterminated continuation")
		failed = 1
	}
	if (val["name"] == "" || val["version"] == "" || val["release"] == "") {
		warn("missing name, version, or release")
		exit 1
	}
	if (val["arch"] == "") val["arch"] = "x86_64"
	val["name"] = expand(val["name"])
	val["version"] = expand(val["version"])
	val["release"] = expand(val["release"])
	val["arch"] = expand(val["arch"])
	val["description"] = expand(val["description"])
	val["depend"] = expand(val["depend"])
	val["builddep"] = expand(val["builddep"])
	val["optional"] = expand(val["optional"])
	val["conflict"] = expand(val["conflict"])
	source = expand(source)
	n = split(pkgpath, parts, "/")
	category = parts[1]
	if (outdir != "") write_page()
	# TSV
	print val["name"] "\t" val["version"] "\t" val["release"] "\t" \
		val["arch"] "\t" repo "\t" category "\t" val["description"] "\t" \
		pkgpath "\t" val["depend"] "\t" val["builddep"] "\t" \
		val["optional"] "\t" val["conflict"] "\t" source
}
