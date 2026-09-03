# Detect a file's GitHub Linguist language from tools/linguist.map.
# mode=detect  -v path= -v shebang=   print name, type, color, group
# mode=count   stdin: size TAB path TAB shebang
#              print group TAB bytes TAB color  (programming+markup only)
# map file: kind key name type color group

function loadmap(    line, f, k) {
	while ((getline line < mapfile) > 0) {
		split(line, f, "\t")
		if (f[1] == "ext") {
			k = tolower(f[2])
			if (!(k in extname)) {
				extname[k] = f[3]
				exttype[k] = f[4]
				extcolor[k] = f[5]
				extgroup[k] = f[6]
			}
		} else if (f[1] == "filename") {
			if (!(f[2] in fnname)) {
				fnname[f[2]] = f[3]
				fntype[f[2]] = f[4]
				fncolor[f[2]] = f[5]
				fngroup[f[2]] = f[6]
			}
		} else if (f[1] == "interpreter") {
			if (!(f[2] in intname)) {
				intname[f[2]] = f[3]
				inttype[f[2]] = f[4]
				intcolor[f[2]] = f[5]
				intgroup[f[2]] = f[6]
			}
		} else if (f[1] == "lang") {
			langtype[f[3]] = f[4]
			langcolor[f[3]] = f[5]
			langgroup[f[3]] = f[6]
		}
	}
	close(mapfile)
	# Linguist heuristics default these ambiguous extensions.
	prefer(".md", "Markdown")
	prefer(".markdown", "Markdown")
	prefer(".scm", "Scheme")
}

function prefer(ext, lang) {
	ext = tolower(ext)
	if (!(lang in langtype))
		return
	extname[ext] = lang
	exttype[ext] = langtype[lang]
	extcolor[ext] = langcolor[lang]
	extgroup[ext] = (langgroup[lang] != "") ? langgroup[lang] : lang
}

function skip_stats(p) {
	return p ~ /(^|\/)(vendor|third_party|node_modules|dist|docs|doc|man|manpages|documentation)\//
}

function interpreter_of(line,    s, n, a, i, cmd) {
	s = line
	sub(/\r$/, "", s)
	if (s !~ /^#!/)
		return ""
	sub(/^#![ \t]*/, "", s)
	n = split(s, a, /[ \t]+/)
	if (n < 1)
		return ""
	cmd = a[1]
	sub(/^.*\//, "", cmd)
	if (cmd == "env" && n >= 2) {
		i = 2
		while (i <= n && a[i] ~ /^-/)
			i++
		if (i <= n)
			cmd = a[i]
		sub(/^.*\//, "", cmd)
	}
	sub(/[0-9]+$/, "", cmd)
	return cmd
}

function detect(path, shebang,    base, interp, p, ext, i, n, parts) {
	d_name = ""
	d_type = ""
	d_color = ""
	d_group = ""
	base = path
	sub(/^.*\//, "", base)

	if (base != "" && (base in fnname)) {
		d_name = fnname[base]
		d_type = fntype[base]
		d_color = fncolor[base]
		d_group = fngroup[base]
		return
	}

	interp = interpreter_of(shebang)
	if (interp != "" && (interp in intname)) {
		d_name = intname[interp]
		d_type = inttype[interp]
		d_color = intcolor[interp]
		d_group = intgroup[interp]
		return
	}

	p = tolower(base)
	n = split(p, parts, /\./)
	if (n >= 2) {
		ext = ""
		for (i = 2; i <= n; i++) {
			if (ext != "")
				ext = ext "."
			ext = ext parts[i]
			key = "." ext
			if (key in extname) {
				d_name = extname[key]
				d_type = exttype[key]
				d_color = extcolor[key]
				d_group = extgroup[key]
			}
		}
		if (d_name != "")
			return
	}

	p = tolower(path)
	n = split(p, parts, /\./)
	if (n >= 2) {
		ext = "." parts[n]
		if (ext in extname) {
			d_name = extname[ext]
			d_type = exttype[ext]
			d_color = extcolor[ext]
			d_group = extgroup[ext]
		}
	}
}

BEGIN {
	FS = "\t"
	OFS = "\t"
	if (mapfile == "")
		mapfile = "tools/linguist.map"
	loadmap()
	if (mode == "count" && filelang != "") {
		printf "" > filelang
		close(filelang)
	}
	if (mode == "detect") {
		detect(path, shebang)
		if (d_name != "")
			print d_name, d_type, d_color, d_group
		exit
	}
}

mode == "count" {
	detect($2, $3)
	if (filelang != "") {
		g = (d_group != "") ? d_group : d_name
		print $2 "\t" d_name "\t" d_type "\t" d_color "\t" $1 "\t" g >> filelang
	}
	if (skip_stats($2))
		next
	if (d_type != "programming" && d_type != "markup")
		next
	g = (d_group != "") ? d_group : d_name
	if (g == "")
		next
	bytes[g] += $1 + 0
	if (!(g in color) && d_color != "")
		color[g] = d_color
}

END {
	if (mode != "count")
		exit
	n = 0
	for (g in bytes) {
		n++
		names[n] = g
		vals[n] = bytes[g]
	}
	# sort by bytes descending
	for (i = 1; i <= n; i++) {
		for (j = i + 1; j <= n; j++) {
			if (vals[j] > vals[i]) {
				t = vals[i]; vals[i] = vals[j]; vals[j] = t
				t = names[i]; names[i] = names[j]; names[j] = t
			}
		}
	}
	for (i = 1; i <= n; i++)
		print names[i], vals[i], color[names[i]]
}
