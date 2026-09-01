# Replace @@HEADER@@ / @@FOOTER@@ / @@ROOT@@ and other tokens.
# headerfile, footerfile, root, rowsfile, and token variables are -v flags.

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

{
	gsub(/@@ROOT@@/, root)
	gsub(/@@RELEASE_TAG@@/, tag)
	gsub(/@@RELEASE_DATE@@/, date)
	gsub(/@@N_PACKAGES@@/, npkgs)
	gsub(/@@N_CORE@@/, ncore)
	gsub(/@@N_EXTRA@@/, nextra)
	gsub(/@@GENERATED@@/, generated)
	gsub(/@@CURL_VER@@/, curlver)
	print
}
