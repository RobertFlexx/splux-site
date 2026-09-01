# Turn collect-news.sh TSV into HTML, a pager, JSON, or Atom.
# Fields: epoch iso kind repo url title summary author verified avatar
# -v mode=html|brief|atom|json|pager
# -v page= -v per= -v pages= -v nest=0|1  -v siteurl=  -v feedupdated=

BEGIN {
	FS = "\t"
	if (mode == "")
		mode = "html"
	if (siteurl == "")
		siteurl = "https://splux.robertflexx.dev"
	per = per + 0
	if (per < 1)
		per = 20
	page = page + 0
	if (page < 1)
		page = 1
	nest = nest + 0
	html_limit = (mode == "brief") ? 8 : 10000
	atom_limit = 200
}

function esc(s) {
	gsub(/&/, "\\&amp;", s)
	gsub(/</, "\\&lt;", s)
	gsub(/>/, "\\&gt;", s)
	gsub(/"/, "\\&quot;", s)
	return s
}

function jesc(s) {
	gsub(/\\/, "\\\\", s)
	gsub(/"/, "\\\"", s)
	gsub(/\t/, " ", s)
	return s
}

function utc_label(iso,    s) {
	s = iso
	sub(/T/, " ", s)
	sub(/:[0-9][0-9](\.[0-9]+)?Z$/, " UTC", s)
	sub(/Z$/, " UTC", s)
	if (s == "")
		return iso
	return s
}

function kind_label(k) {
	if (k == "release")
		return "release"
	return "commit"
}

function page_href(p) {
	if (nest) {
		if (p <= 1)
			return "../"
		return "../" p "/"
	}
	if (p <= 1)
		return "./"
	return p "/"
}

{
	n++
	epoch[n] = $1
	iso[n] = $2
	kind[n] = $3
	repo[n] = $4
	url[n] = $5
	title[n] = $6
	summary[n] = $7
	author[n] = $8
	verified[n] = $9
	avatar[n] = $10
}

END {
	if (mode == "atom") {
		print_atom()
		exit
	}
	if (mode == "json") {
		print_json()
		exit
	}
	if (mode == "pager") {
		print_pager()
		exit
	}
	if (n == 0) {
		print "<p class=\"note\">No GitHub events were available when this page was built.</p>"
		exit
	}
	print "<div class=\"feed\">"
	if (mode == "brief") {
		limit = html_limit
		if (n < limit)
			limit = n
		for (i = 1; i <= limit; i++)
			print_item(i, 1)
	} else {
		start = (page - 1) * per + 1
		stop = start + per - 1
		if (start < 1)
			start = 1
		if (stop > n)
			stop = n
		for (i = start; i <= stop; i++)
			print_item(i, 0)
	}
	print "</div>"
}

function print_item(i, brief,    k, when, s, v, a, av) {
	when = esc(utc_label(iso[i]))
	k = esc(kind_label(kind[i]))
	a = author[i]
	v = verified[i]
	av = avatar[i]
	printf "<article class=\"item\" data-kind=\"%s\" data-repo=\"%s\" data-author=\"%s\" data-verified=\"%s\" data-avatar=\"%s\">\n", \
		k, esc(repo[i]), esc(a), esc(v), esc(av)
	printf "<p class=\"meta\"><time datetime=\"%s\">%s</time> <span class=\"kind\">%s</span> %s", \
		esc(iso[i]), when, k, esc(repo[i])
	if (a != "" || av != "") {
		printf " <span class=\"who\">"
		if (av != "")
			printf "<img class=\"avatar\" src=\"%s\" width=\"24\" height=\"24\" alt=\"\" loading=\"lazy\">", esc(av)
		if (a != "")
			printf "%s", esc(a)
		printf "</span>"
	}
	if (v == "yes")
		printf " <span class=\"verified\">verified</span>"
	print "</p>"
	printf "<h3><a href=\"%s\">%s</a></h3>\n", esc(url[i]), esc(title[i])
	if (!brief) {
		s = summary[i]
		if (s != "")
			printf "<p class=\"summary\">%s</p>\n", esc(s)
	}
	print "</article>"
}

function print_pager(    i, lo, hi, prev, shown, need_dots) {
	pages = pages + 0
	if (pages < 1)
		pages = 1
	if (page < 1)
		page = 1
	if (page > pages)
		page = pages
	if (pages <= 1) {
		printf "<nav class=\"pager\" id=\"news-pager\" hidden data-page=\"1\" data-pages=\"1\" data-per=\"%d\" aria-label=\"News pages\"></nav>\n", per
		return
	}
	lo = page - 2
	hi = page + 2
	if (lo < 1) {
		hi += (1 - lo)
		lo = 1
	}
	if (hi > pages) {
		lo -= (hi - pages)
		hi = pages
	}
	if (lo < 1)
		lo = 1
	printf "<nav class=\"pager\" id=\"news-pager\" data-page=\"%d\" data-pages=\"%d\" data-per=\"%d\" aria-label=\"News pages\">\n", \
		page, pages, per
	printf "<p class=\"pager-status\">Page %d of %d</p>\n", page, pages
	print "<p class=\"pager-links\">"
	if (page > 1)
		printf "<a rel=\"prev\" href=\"%s\">prev</a>\n", esc(page_href(page - 1))
	need_dots = 0
	for (i = 1; i <= pages; i++) {
		shown = (i == 1 || i == pages || (i >= lo && i <= hi))
		if (!shown) {
			need_dots = 1
			continue
		}
		if (need_dots) {
			print "<span class=\"pager-gap\">...</span>"
			need_dots = 0
		}
		if (i == page)
			printf "<a href=\"%s\" aria-current=\"page\">%d</a>\n", \
				esc(page_href(i)), i
		else
			printf "<a href=\"%s\">%d</a>\n", esc(page_href(i)), i
	}
	if (page < pages)
		printf "<a rel=\"next\" href=\"%s\">next</a>\n", esc(page_href(page + 1))
	print "</p>"
	print "<form class=\"pager-jump\" id=\"news-jump\" action=\"#\">"
	printf "<label for=\"news-page-n\">Go to page</label>\n"
	printf "<input id=\"news-page-n\" name=\"n\" type=\"number\" min=\"1\" max=\"%d\" value=\"%d\" inputmode=\"numeric\">\n", \
		pages, page
	print "<button type=\"submit\">Go</button>"
	print "</form>"
	print "</nav>"
}

function print_json(    i, v) {
	print "["
	for (i = 1; i <= n; i++) {
		if (i > 1)
			print ","
		v = (verified[i] == "yes") ? "true" : "false"
		printf "{\"iso\":\"%s\",\"kind\":\"%s\",\"repo\":\"%s\",\"url\":\"%s\",\"title\":\"%s\",\"summary\":\"%s\",\"author\":\"%s\",\"verified\":%s,\"avatar\":\"%s\"}", \
			jesc(iso[i]), jesc(kind_label(kind[i])), jesc(repo[i]), \
			jesc(url[i]), jesc(title[i]), jesc(summary[i]), \
			jesc(author[i]), v, jesc(avatar[i])
	}
	print "\n]"
}

function print_atom(    i, limit, updated) {
	updated = feedupdated
	if (updated == "" && n > 0)
		updated = iso[1]
	if (updated == "")
		updated = "1970-01-01T00:00:00Z"
	print "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
	print "<feed xmlns=\"http://www.w3.org/2005/Atom\">"
	print "<title>Splux Linux news</title>"
	printf "<link rel=\"self\" href=\"%s/news/atom.xml\"/>\n", esc(siteurl)
	printf "<link href=\"%s/news/\"/>\n", esc(siteurl)
	printf "<updated>%s</updated>\n", esc(updated)
	printf "<id>%s/news/</id>\n", esc(siteurl)
	print "<author><name>RobertFlexx</name></author>"
	limit = atom_limit
	if (n < limit)
		limit = n
	for (i = 1; i <= limit; i++) {
		print "<entry>"
		printf "<title>%s</title>\n", esc(title[i])
		printf "<link href=\"%s\"/>\n", esc(url[i])
		printf "<id>%s</id>\n", esc(url[i])
		printf "<updated>%s</updated>\n", esc(iso[i])
		printf "<category term=\"%s\"/>\n", esc(kind[i])
		printf "<summary>%s</summary>\n", esc(repo[i] ": " title[i])
		print "</entry>"
	}
	print "</feed>"
}
