# HTML fragments for the static Splux Git browser.
# mode=one       escape $0 (or -v text=) as one HTML string
# mode=pre       escape stdin as a <pre class="block git-blob">
# mode=langs     TSV lang<TAB>bytes -> bar plus list
# mode=commits   TSV hash short epoch iso subject author
#                -v commitpfx= relative prefix ending in commit/
# mode=entries   TSV kind size name href  (kind=dir|file)

function esc(s) {
	gsub(/&/, "\\&amp;", s)
	gsub(/</, "\\&lt;", s)
	gsub(/>/, "\\&gt;", s)
	gsub(/"/, "\\&quot;", s)
	return s
}

function pct(n, d) {
	if (d <= 0)
		return 0
	return int((n * 1000) / d) / 10
}

BEGIN {
	FS = "\t"
	limit = limit + 0
	if (mode == "one") {
		if (text != "")
			printf "%s", esc(text)
		else {
			while ((getline line) > 0)
				printf "%s", esc(line)
		}
		exit
	}
}

mode == "pre" {
	if (!opened) {
		print "<pre class=\"block git-blob\">"
		opened = 1
	}
	print esc($0)
}

mode == "langs" {
	n++
	lang[n] = $1
	bytes[n] = $2 + 0
	total += bytes[n]
}

mode == "commits" {
	if (limit > 0 && n >= limit)
		next
	n++
	hash[n] = $1
	short[n] = $2
	iso[n] = $4
	subject[n] = $5
	author[n] = $6
}

mode == "entries" {
	n++
	kind[n] = $1
	size[n] = $2
	name[n] = $3
	href[n] = $4
}

END {
	if (mode == "pre") {
		if (!opened)
			print "<pre class=\"block git-blob\"></pre>"
		else
			print "</pre>"
		exit
	}
	if (mode == "langs") {
		if (n < 1)
			exit
		print "<div class=\"lang-bar\" role=\"img\" aria-label=\"Languages\">"
		for (i = 1; i <= n; i++) {
			w = pct(bytes[i], total)
			if (w <= 0 && bytes[i] > 0)
				w = 0.1
			printf "<span class=\"lang-seg\" style=\"width:%s%%\" title=\"%s %s%%\"></span>\n", \
				w, esc(lang[i]), w
		}
		print "</div>"
		print "<ul class=\"lang-list\">"
		for (i = 1; i <= n; i++)
			printf "<li>%s <span class=\"muted\">%s%%</span></li>\n", \
				esc(lang[i]), pct(bytes[i], total)
		print "</ul>"
		exit
	}
	if (mode == "commits") {
		print "<table class=\"pkgs git-log\">"
		print "<thead><tr><th>Commit</th><th>Subject</th><th>Author</th><th>When</th></tr></thead>"
		print "<tbody>"
		for (i = 1; i <= n; i++) {
			href = commitpfx esc(hash[i]) "/"
			day = iso[i]
			sub(/T.*/, "", day)
			printf "<tr>"
			printf "<td><a href=\"%s\"><code>%s</code></a></td>", href, esc(short[i])
			printf "<td><a href=\"%s\">%s</a></td>", href, esc(subject[i])
			printf "<td>%s</td>", esc(author[i])
			printf "<td><time datetime=\"%s\">%s</time></td>", esc(iso[i]), esc(day)
			print "</tr>"
		}
		print "</tbody></table>"
		exit
	}
	if (mode == "entries") {
		print "<table class=\"pkgs git-tree\">"
		print "<thead><tr><th></th><th>Name</th><th>Size</th></tr></thead>"
		print "<tbody>"
		for (i = 1; i <= n; i++) {
			label = kind[i] == "dir" ? "dir" : "file"
			sz = kind[i] == "dir" ? "" : size[i]
			printf "<tr data-search=\"%s\">", esc(tolower(name[i]))
			printf "<td class=\"muted\">%s</td>", label
			printf "<td><a href=\"%s\">%s</a></td>", esc(href[i]), esc(name[i])
			printf "<td class=\"muted\">%s</td>", esc(sz)
			print "</tr>"
		}
		print "</tbody></table>"
		exit
	}
}
