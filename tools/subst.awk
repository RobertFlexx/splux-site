# Replace @@HEADER@@ / @@FOOTER@@ / @@ROOT@@ and other tokens.
# headerfile, footerfile, root, rowsfile, and token variables are -v flags.

function dump_file(path,    line) {
	if (path == "")
		return
	while ((getline line < path) > 0)
		print line
	close(path)
}

BEGIN {
	if (headerfile != "") {
		while ((getline line < headerfile) > 0)
			header = header line "\n"
		close(headerfile)
	}
	if (footerfile != "") {
		while ((getline line < footerfile) > 0)
			footer = footer line "\n"
		close(footerfile)
	}
	if (githost == "")
		githost = "https://splux.robertflexx.dev/git"
}

$0 == "@@HEADER@@" {
	printf "%s", header
	next
}

$0 == "@@FOOTER@@" {
	printf "%s", footer
	next
}

$0 == "@@PKG_ROWS@@" {
	if (rowsfile != "") {
		while ((getline line < rowsfile) > 0) {
			gsub(/@@ROOT@@/, root, line)
			print line
		}
		close(rowsfile)
	}
	next
}

$0 == "@@NEWS@@" {
	dump_file(newsfile)
	next
}

$0 == "@@NEWS_BRIEF@@" {
	dump_file(brieffile)
	next
}

$0 == "@@NEWS_INFO@@" {
	dump_file(infofile)
	next
}

$0 == "@@PAGER@@" {
	dump_file(pagerfile)
	next
}

$0 == "@@DOCSNAV@@" {
	dump_file(docsnavfile)
	next
}

{
	gsub(/@@ROOT@@/, root)
	gsub(/@@RELEASE_TAG@@/, tag)
	gsub(/@@RELEASE_DATE@@/, date)
	gsub(/@@N_PACKAGES@@/, npkgs)
	gsub(/@@N_CORE@@/, ncore)
	gsub(/@@N_EXTRA@@/, nextra)
	gsub(/@@GENERATED@@/, generated)
	gsub(/@@LIVE_SIG@@/, livesig)
	gsub(/@@CURL_VER@@/, curlver)
	gsub(/@@NEWS_PAGE_TITLE@@/, pagetitle)
	gsub(/@@GIT_HOST@@/, githost)
	print
}
