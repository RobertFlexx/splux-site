# HTML fragments for the static Splux Git browser.
# mode=one       escape $0 (or -v text=) as one HTML string
# mode=who       -v login= -v name= -v avatar= -v verified= -v userpfx=
# mode=pre       escape stdin as a <pre class="block git-blob">
# mode=langs     TSV lang<TAB>bytes<TAB>color
# mode=commits   TSV hash short epoch iso subject author login avatar verified [repo]
#                -v commitpfx=  -v userpfx=  -v repopfx=
# mode=people    TSV login avatar count
#                -v userpfx=
# mode=entries   TSV kind size name href [lang]

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
	return int((n * 1000 + d / 2) / d) / 10
}

function who(login, name, avatar,    html, av, label) {
	label = login != "" ? login : name
	if (login != "") {
		av = avatar
		if (av == "")
			av = "https://github.com/" login ".png?size=48"
		html = "<a class=\"who\" href=\"" userpfx esc(login) "/\">"
		html = html "<img class=\"avatar\" src=\"" esc(av) \
			"\" width=\"24\" height=\"24\" alt=\"\" loading=\"lazy\">"
		html = html esc(login) "</a>"
		return html
	}
	return esc(name)
}

BEGIN {
	FS = "\t"
	limit = limit + 0
	if (userpfx == "")
		userpfx = "../users/"
	if (mode == "one") {
		if (text != "")
			printf "%s", esc(text)
		else {
			while ((getline line) > 0)
				printf "%s", esc(line)
		}
		exit
	}
	if (mode == "who") {
		printf "%s", who(login, name, avatar)
		if (verified == "yes")
			printf " <span class=\"verified\">verified</span>"
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
	col[n] = $3
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
	login[n] = $7
	avatar[n] = $8
	verified[n] = $9
	repo[n] = $10
}

mode == "people" {
	n++
	login[n] = $1
	avatar[n] = $2
	count[n] = $3
}

mode == "entries" {
	n++
	kind[n] = $1
	size[n] = $2
	name[n] = $3
	href[n] = $4
	elang[n] = $5
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
			style = "width:" w "%"
			if (col[i] != "")
				style = style ";background:" col[i]
			printf "<span class=\"lang-seg\" style=\"%s\" title=\"%s %s%%\"></span>\n", \
				style, esc(lang[i]), w
		}
		print "</div>"
		print "<ul class=\"lang-list\">"
		for (i = 1; i <= n; i++)
			printf "<li><span class=\"lang-dot\" style=\"background:%s\"></span> %s <span class=\"muted\">%s%%</span></li>\n", \
				esc(col[i] != "" ? col[i] : "#888888"), esc(lang[i]), pct(bytes[i], total)
		print "</ul>"
		exit
	}
	if (mode == "commits") {
		print "<table class=\"pkgs git-log\">"
		if (repopfx != "")
			print "<thead><tr><th>Commit</th><th>Repository</th><th>Subject</th><th>Author</th><th>When</th></tr></thead>"
		else
			print "<thead><tr><th>Commit</th><th>Subject</th><th>Author</th><th>When</th></tr></thead>"
		print "<tbody>"
		for (i = 1; i <= n; i++) {
			day = iso[i]
			sub(/T.*/, "", day)
			if (repopfx != "" && repo[i] != "")
				href = repopfx esc(repo[i]) "/commit/" esc(hash[i]) "/"
			else
				href = commitpfx esc(hash[i]) "/"
			printf "<tr data-sha=\"%s\" data-login=\"%s\" data-repo=\"%s\">", \
				esc(hash[i]), esc(login[i]), esc(repo[i])
			printf "<td><a href=\"%s\"><code>%s</code></a></td>", href, esc(short[i])
			if (repopfx != "")
				printf "<td><a href=\"%s%s/\">%s</a></td>", \
					repopfx, esc(repo[i]), esc(repo[i])
			printf "<td><a href=\"%s\">%s</a></td>", href, esc(subject[i])
			printf "<td>%s", who(login[i], author[i], avatar[i])
			if (verified[i] == "yes")
				printf " <span class=\"verified\">verified</span>"
			printf "</td>"
			printf "<td><time datetime=\"%s\">%s</time></td>", esc(iso[i]), esc(day)
			print "</tr>"
		}
		print "</tbody></table>"
		exit
	}
	if (mode == "people") {
		print "<div class=\"people\" id=\"git-people\">"
		for (i = 1; i <= n; i++) {
			printf "<span class=\"person\">%s", who(login[i], login[i], avatar[i])
			if (count[i] != "")
				printf " <span class=\"muted\">%s</span>", esc(count[i])
			print "</span>"
		}
		print "</div>"
		exit
	}
	if (mode == "entries") {
		print "<table class=\"pkgs git-tree\">"
		print "<thead><tr><th></th><th>Name</th><th>Language</th><th>Size</th></tr></thead>"
		print "<tbody>"
		for (i = 1; i <= n; i++) {
			label = kind[i] == "dir" ? "dir" : "file"
			sz = kind[i] == "dir" ? "" : size[i]
			printf "<tr data-search=\"%s %s\">", esc(tolower(name[i])), esc(tolower(elang[i]))
			printf "<td class=\"muted\">%s</td>", label
			printf "<td><a href=\"%s\">%s</a></td>", esc(href[i]), esc(name[i])
			printf "<td class=\"muted\">%s</td>", esc(elang[i])
			printf "<td class=\"muted\">%s</td>", esc(sz)
			print "</tr>"
		}
		print "</tbody></table>"
		exit
	}
}
