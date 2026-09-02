# Flatten github-linguist languages.yml into TSV.
# kind key name type color group
# kind is ext, filename, interpreter, or lang.

BEGIN {
	OFS = "\t"
}

function trim(s) {
	sub(/^[ \t]+/, "", s)
	sub(/[ \t]+$/, "", s)
	return s
}

function unquote(s) {
	s = trim(s)
	if (s ~ /^".*"$/) {
		s = substr(s, 2, length(s) - 2)
		gsub(/\\"/, "\"", s)
	}
	return s
}

function emit_lang() {
	if (name == "")
		return
	g = (group != "") ? group : name
	c = (color != "") ? color : ""
	t = (typ != "") ? typ : "data"
	print "lang", name, name, t, c, g
}

function emit(kind, key) {
	if (name == "" || key == "")
		return
	g = (group != "") ? group : name
	c = (color != "") ? color : ""
	t = (typ != "") ? typ : "data"
	print kind, key, name, t, c, g
}

/^---$/ { next }
/^#/ { next }
/^$/ { next }

/^[^ \t]/ {
	if ($0 ~ /:$/) {
		emit_lang()
		name = $0
		sub(/:$/, "", name)
		typ = ""
		color = ""
		group = ""
		section = ""
	}
	next
}

/^[ \t]+[a-z_]+:/ {
	key = trim($1)
	sub(/:$/, "", key)
	rest = $0
	sub(/^[ \t]+[a-z_]+:[ \t]*/, "", rest)
	rest = trim(rest)
	if (key == "type")
		typ = unquote(rest)
	else if (key == "color")
		color = unquote(rest)
	else if (key == "group")
		group = unquote(rest)
	if (key == "extensions")
		section = "ext"
	else if (key == "filenames")
		section = "filename"
	else if (key == "interpreters")
		section = "interpreter"
	else
		section = ""
	next
}

/^[ \t]+- / {
	item = $0
	sub(/^[ \t]+- [ \t]*/, "", item)
	item = unquote(item)
	if (section != "" && item != "")
		emit(section, item)
	next
}

END {
	emit_lang()
}
