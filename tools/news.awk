# Turn collect-news.sh TSV into HTML or Atom.
# Fields: epoch iso kind repo url title summary
# -v mode=html|brief|atom  -v siteurl=  -v feedupdated=

BEGIN {
	FS = "\t"
	if (mode == "")
		mode = "html"
	if (siteurl == "")
		siteurl = "https://splux.robertflexx.dev"
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

function day_of(iso,    d) {
	d = iso
	sub(/T.*/, "", d)
	return d
}

function kind_label(k) {
	if (k == "release")
		return "release"
	return "commit"
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
}

END {
	if (mode == "atom") {
		print_atom()
		exit
	}
	if (n == 0) {
		print "<p class=\"note\">No GitHub events were available when this page was built.</p>"
		exit
	}
	print "<div class=\"feed\">"
	limit = html_limit
	if (n < limit)
		limit = n
	for (i = 1; i <= limit; i++) {
		print_item(i, mode == "brief")
	}
	print "</div>"
}

function print_item(i, brief,    k, when, s) {
	when = esc(day_of(iso[i]))
	k = esc(kind_label(kind[i]))
	print "<article class=\"item\">"
	printf "<p class=\"meta\"><time datetime=\"%s\">%s</time> <span class=\"kind\">%s</span> %s</p>\n", \
		esc(iso[i]), when, k, esc(repo[i])
	printf "<h3><a href=\"%s\">%s</a></h3>\n", esc(url[i]), esc(title[i])
	if (!brief) {
		s = summary[i]
		if (s != "")
			printf "<p class=\"summary\">%s</p>\n", esc(s)
	}
	print "</article>"
}

function print_atom(    i, limit, updated, id) {
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
