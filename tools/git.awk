# HTML fragments for the static Splux Git browser.
# mode=one       escape $0 (or -v text=) as one HTML string
# mode=who       -v login= -v name= -v avatar= -v verified= -v userpfx=
# mode=pre       escape stdin as a <pre class="block git-blob">
# mode=langs     TSV lang<TAB>bytes<TAB>color[<TAB>nfiles]
#                -v langpfx=
# mode=langindex TSV lang<TAB>ghbytes<TAB>color<TAB>nfiles<TAB>filebytes
#                -v langpfx=
# mode=commits   TSV hash short epoch iso subject author login avatar verified [repo]
#                -v commitpfx=  -v userpfx=  -v repopfx=
# mode=people    TSV login avatar count [name]
#                -v userpfx=
# mode=peoplelist TSV login avatar count name iso subject hash
#                -v userpfx= -v commitpfx=
# mode=entries   TSV kind size name href [lang]
#                -v langpfx=  -v showlang=no

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

function slug(s) {
	gsub(/[ \/]/, "-", s)
	return s
}

function langhref(name) {
	if (langpfx == "" || name == "")
		return ""
	return langpfx slug(name) "/"
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
		userpfx = "@@ROOT@@git/users/"
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
	nfiles[n] = $4 + 0
	total += bytes[n]
}

mode == "langindex" {
	n++
	lang[n] = $1
	bytes[n] = $2 + 0
	col[n] = $3
	nfiles[n] = $4 + 0
	fbytes[n] = $5 + 0
	total += (bytes[n] > 0) ? bytes[n] : fbytes[n]
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
	pname[n] = $4
}

mode == "peoplelist" {
	n++
	login[n] = $1
	avatar[n] = $2
	count[n] = $3
	pname[n] = $4
	iso[n] = $5
	subject[n] = $6
	hash[n] = $7
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
			href = langhref(lang[i])
			title = esc(lang[i]) " " w "%"
			if (href != "")
				printf "<a class=\"lang-seg\" href=\"%s\" style=\"%s\" title=\"%s\"></a>\n", \
					esc(href), style, title
			else
				printf "<span class=\"lang-seg\" style=\"%s\" title=\"%s\"></span>\n", \
					style, title
		}
		print "</div>"
		print "<ul class=\"lang-list\">"
		for (i = 1; i <= n; i++) {
			href = langhref(lang[i])
			dot = esc(col[i] != "" ? col[i] : "#888888")
			extra = pct(bytes[i], total) "%"
			if (nfiles[i] > 0)
				extra = extra " · " nfiles[i] " files"
			if (href != "")
				printf "<li><a href=\"%s\"><span class=\"lang-dot\" style=\"background:%s\"></span> %s <span class=\"muted\">%s</span></a></li>\n", \
					esc(href), dot, esc(lang[i]), extra
			else
				printf "<li><span class=\"lang-dot\" style=\"background:%s\"></span> %s <span class=\"muted\">%s</span></li>\n", \
					dot, esc(lang[i]), extra
		}
		print "</ul>"
		exit
	}
	if (mode == "langindex") {
		print "<table class=\"pkgs git-langs\" id=\"git-lang-table\">"
		print "<thead><tr><th>Language</th><th>Files</th><th>Bytes</th><th></th></tr></thead>"
		print "<tbody>"
		for (i = 1; i <= n; i++) {
			href = langhref(lang[i])
			dot = esc(col[i] != "" ? col[i] : "#888888")
			sz = bytes[i] > 0 ? bytes[i] : fbytes[i]
			w = pct(sz, total)
			printf "<tr data-search=\"%s\">", esc(tolower(lang[i]))
			printf "<td>"
			if (href != "")
				printf "<a href=\"%s\"><span class=\"lang-dot\" style=\"background:%s\"></span> %s</a>", \
					esc(href), dot, esc(lang[i])
			else
				printf "<span class=\"lang-dot\" style=\"background:%s\"></span> %s", \
					dot, esc(lang[i])
			printf "</td>"
			printf "<td class=\"muted\">%s</td>", (nfiles[i] > 0 ? nfiles[i] : "")
			printf "<td class=\"muted\">%s</td>", (sz > 0 ? sz : "")
			printf "<td class=\"muted\">%s%%</td>", w
			print "</tr>"
		}
		print "</tbody></table>"
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
			if (repopfx != "" && repo[i] != "")
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
			label = pname[i] != "" ? pname[i] : login[i]
			printf "<span class=\"person\">%s", who(login[i], label, avatar[i])
			if (count[i] != "")
				printf " <span class=\"muted\">%s</span>", esc(count[i])
			print "</span>"
		}
		print "</div>"
		exit
	}
	if (mode == "peoplelist") {
		print "<table class=\"pkgs git-people\" id=\"git-people-table\">"
		print "<thead><tr><th>Person</th><th>Commits</th><th>Last commit</th><th>When</th></tr></thead>"
		print "<tbody>"
		for (i = 1; i <= n; i++) {
			label = pname[i] != "" ? pname[i] : login[i]
			search = tolower(login[i] " " label)
			printf "<tr data-login=\"%s\" data-search=\"%s\">", \
				esc(login[i]), esc(search)
			printf "<td>%s</td>", who(login[i], label, avatar[i])
			printf "<td class=\"muted\">%s</td>", esc(count[i])
			if (hash[i] != "" && commitpfx != "") {
				chref = commitpfx esc(hash[i]) "/"
				printf "<td><a href=\"%s\">%s</a></td>", chref, esc(subject[i])
			} else
				printf "<td>%s</td>", esc(subject[i])
			day = iso[i]
			sub(/T.*/, "", day)
			if (iso[i] != "")
				printf "<td><time datetime=\"%s\">%s</time></td>", \
					esc(iso[i]), esc(day)
			else
				printf "<td></td>"
			print "</tr>"
		}
		print "</tbody></table>"
		exit
	}
	if (mode == "entries") {
		print "<table class=\"pkgs git-tree\">"
		if (showlang == "no")
			print "<thead><tr><th></th><th>Name</th><th>Size</th></tr></thead>"
		else
			print "<thead><tr><th></th><th>Name</th><th>Language</th><th>Size</th></tr></thead>"
		print "<tbody>"
		for (i = 1; i <= n; i++) {
			label = kind[i] == "dir" ? "dir" : "file"
			sz = kind[i] == "dir" ? "" : size[i]
			printf "<tr data-search=\"%s %s\">", esc(tolower(name[i])), esc(tolower(elang[i]))
			printf "<td class=\"muted\">%s</td>", label
			printf "<td><a href=\"%s\">%s</a></td>", esc(href[i]), esc(name[i])
			if (showlang != "no") {
				lhref = langhref(elang[i])
				if (lhref != "" && elang[i] != "")
					printf "<td><a href=\"%s\">%s</a></td>", esc(lhref), esc(elang[i])
				else
					printf "<td class=\"muted\">%s</td>", esc(elang[i])
			}
			printf "<td class=\"muted\">%s</td>", esc(sz)
			print "</tr>"
		}
		print "</tbody></table>"
		exit
	}
}
