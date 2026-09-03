# Highlight source and render Markdown for Splux Git.
# mode=highlight  stdin -> <pre class="block git-blob is-hl">  -v lang=
# mode=markdown   stdin -> HTML  (fenced code uses the highlighter)
# -v mapfile=tools/linguist.map  maps Linguist names onto highlighter families

function esc(s) {
	gsub(/&/, "\\&amp;", s)
	gsub(/</, "\\&lt;", s)
	gsub(/>/, "\\&gt;", s)
	gsub(/"/, "\\&quot;", s)
	return s
}

function kadd(key, words,    n, a, i) {
	n = split(words, a, /[ \t]+/)
	for (i = 1; i <= n; i++)
		if (a[i] != "")
			KW[key SUBSEP a[i]] = 1
}

function iskw(lang, fam, w) {
	return (lang SUBSEP w) in KW || (fam SUBSEP w) in KW
}

function sp(cls, s) {
	if (s == "")
		return ""
	return "<span class=\"" cls "\">" esc(s) "</span>"
}

function load_langmap(    line, f) {
	if (mapfile == "")
		mapfile = "tools/linguist.map"
	while ((getline line < mapfile) > 0) {
		split(line, f, "\t")
		if (f[1] == "lang" && f[3] != "") {
			LGROUP[f[3]] = (f[6] != "") ? f[6] : f[3]
			LTYPE[f[3]] = f[4]
		}
	}
	close(mapfile)
}

function setfam(name, fam) {
	FAM[name] = fam
}

function load_fams() {
	setfam("Shell", "shell"); setfam("Bash", "shell"); setfam("Zsh", "shell")
	setfam("Fish", "shell"); setfam("Nushell", "shell")
	setfam("PowerShell", "shell"); setfam("Batchfile", "shell")
	setfam("Alpine Abuild", "shell"); setfam("Gentoo Ebuild", "shell")
	setfam("C", "clike"); setfam("C++", "clike"); setfam("C#", "clike")
	setfam("Objective-C", "clike"); setfam("Objective-C++", "clike")
	setfam("Java", "clike"); setfam("JavaScript", "clike")
	setfam("TypeScript", "clike"); setfam("Go", "clike"); setfam("Rust", "clike")
	setfam("PHP", "clike"); setfam("Kotlin", "clike"); setfam("Scala", "clike")
	setfam("Swift", "clike"); setfam("Dart", "clike"); setfam("D", "clike")
	setfam("Groovy", "clike"); setfam("Apex", "clike"); setfam("Vala", "clike")
	setfam("Zig", "clike"); setfam("Carbon", "clike"); setfam("V", "clike")
	setfam("Nim", "clike"); setfam("Crystal", "clike")
	setfam("Python", "python"); setfam("Starlark", "python")
	setfam("Cython", "python"); setfam("Snakemake", "python")
	setfam("Ruby", "ruby"); setfam("Perl", "perl"); setfam("Raku", "perl")
	setfam("Awk", "awk"); setfam("Lua", "lua"); setfam("R", "r")
	setfam("Tcl", "tcl"); setfam("SQL", "sql"); setfam("PLpgSQL", "sql")
	setfam("TSQL", "sql"); setfam("PLSQL", "sql")
	setfam("HTML", "xml"); setfam("XML", "xml"); setfam("SVG", "xml")
	setfam("XSLT", "xml"); setfam("Vue", "xml"); setfam("Svelte", "xml")
	setfam("Astro", "xml"); setfam("JSX", "xml"); setfam("TSX", "xml")
	setfam("CSS", "css"); setfam("SCSS", "css"); setfam("Sass", "css")
	setfam("Less", "css"); setfam("PostCSS", "css")
	setfam("JSON", "json"); setfam("JSON5", "json"); setfam("JSONC", "json")
	setfam("JSON with Comments", "json")
	setfam("YAML", "yaml"); setfam("TOML", "toml"); setfam("INI", "ini")
	setfam("Desktop", "ini"); setfam("Git Config", "ini")
	setfam("Makefile", "make"); setfam("CMake", "cmake")
	setfam("Diff", "diff"); setfam("Ignore List", "ini")
	setfam("Lisp", "lisp"); setfam("Scheme", "lisp")
	setfam("Common Lisp", "lisp"); setfam("Emacs Lisp", "lisp")
	setfam("Clojure", "lisp"); setfam("Racket", "lisp")
	setfam("Haskell", "haskell"); setfam("Idris", "haskell")
	setfam("Elixir", "elixir"); setfam("Erlang", "erlang")
	setfam("Fortran", "fortran"); setfam("Fortran Free Form", "fortran")
	setfam("Vim Script", "vim"); setfam("Vim Help File", "vim")
	setfam("Dockerfile", "docker"); setfam("Nix", "nix")
	setfam("Protocol Buffer", "proto"); setfam("GraphQL", "graphql")
	setfam("TeX", "tex"); setfam("LaTeX", "tex"); setfam("BibTeX", "tex")
	setfam("Assembly", "asm"); setfam("Unix Assembly", "asm")
	setfam("Markdown", "markdown"); setfam("MDX", "markdown")
	setfam("AsciiDoc", "markdown"); setfam("reStructuredText", "markdown")
	setfam("Pod", "markdown"); setfam("RDoc", "markdown")
	setfam("Text", "plain"); setfam("Gettext Catalog", "plain")
	FENCE["sh"] = "Shell"; FENCE["bash"] = "Shell"; FENCE["zsh"] = "Shell"
	FENCE["shell"] = "Shell"; FENCE["fish"] = "Shell"
	FENCE["js"] = "JavaScript"; FENCE["javascript"] = "JavaScript"
	FENCE["ts"] = "TypeScript"; FENCE["typescript"] = "TypeScript"
	FENCE["jsx"] = "JavaScript"; FENCE["tsx"] = "TypeScript"
	FENCE["py"] = "Python"; FENCE["python"] = "Python"
	FENCE["rb"] = "Ruby"; FENCE["ruby"] = "Ruby"
	FENCE["pl"] = "Perl"; FENCE["perl"] = "Perl"
	FENCE["lua"] = "Lua"; FENCE["sql"] = "SQL"
	FENCE["c"] = "C"; FENCE["h"] = "C"; FENCE["cpp"] = "C++"; FENCE["c++"] = "C++"
	FENCE["cc"] = "C++"; FENCE["hpp"] = "C++"; FENCE["rs"] = "Rust"
	FENCE["rust"] = "Rust"; FENCE["go"] = "Go"; FENCE["golang"] = "Go"
	FENCE["java"] = "Java"; FENCE["kt"] = "Kotlin"; FENCE["cs"] = "C#"
	FENCE["php"] = "PHP"; FENCE["swift"] = "Swift"; FENCE["dart"] = "Dart"
	FENCE["html"] = "HTML"; FENCE["xml"] = "XML"; FENCE["svg"] = "SVG"
	FENCE["css"] = "CSS"; FENCE["scss"] = "SCSS"; FENCE["json"] = "JSON"
	FENCE["yml"] = "YAML"; FENCE["yaml"] = "YAML"; FENCE["toml"] = "TOML"
	FENCE["md"] = "Markdown"; FENCE["markdown"] = "Markdown"
	FENCE["mdx"] = "Markdown"; FENCE["mdown"] = "Markdown"
	FENCE["awk"] = "Awk"; FENCE["make"] = "Makefile"; FENCE["makefile"] = "Makefile"
	FENCE["mjs"] = "JavaScript"; FENCE["cjs"] = "JavaScript"
	FENCE["pyi"] = "Python"; FENCE["hh"] = "C++"; FENCE["cxx"] = "C++"
	FENCE["kts"] = "Kotlin"; FENCE["exs"] = "Elixir"; FENCE["gql"] = "GraphQL"
	FENCE["s"] = "Assembly"; FENCE["vue"] = "Vue"
	FENCE["diff"] = "Diff"; FENCE["patch"] = "Diff"
	FENCE["dockerfile"] = "Dockerfile"; FENCE["docker"] = "Dockerfile"
	FENCE["nix"] = "Nix"; FENCE["cmake"] = "CMake"; FENCE["r"] = "R"
	FENCE["hs"] = "Haskell"; FENCE["lisp"] = "Lisp"; FENCE["el"] = "Emacs Lisp"
	FENCE["vim"] = "Vim Script"; FENCE["elixir"] = "Elixir"
	FENCE["ex"] = "Elixir"; FENCE["erl"] = "Erlang"
	FENCE["proto"] = "Protocol Buffer"; FENCE["graphql"] = "GraphQL"
	FENCE["tex"] = "TeX"; FENCE["latex"] = "TeX"; FENCE["asm"] = "Assembly"
	FENCE["ini"] = "INI"; FENCE["conf"] = "INI"; FENCE["cfg"] = "INI"
}

function load_kw() {
	kadd("clike", "if else for while do switch case default break continue return goto sizeof typedef struct union enum const static extern volatile register auto void int char short long float double signed unsigned bool true false NULL nullptr this new delete try catch throw class public private protected namespace using template typename virtual override final inline explicit friend operator constexpr static_assert alignas alignof noexcept decltype thread_local")
	kadd("C", "restrict _Bool _Complex _Imaginary _Atomic _Static_assert _Generic _Alignas _Alignof _Noreturn _Thread_local")
	kadd("C++", "and and_eq bitand bitor compl not not_eq or or_eq xor xor_eq concept requires co_await co_yield co_return import module export consteval constinit")
	kadd("JavaScript", "function var let const async await yield import export from as of in instanceof typeof new this class extends super constructor get set of with debugger NaN Infinity undefined null true false")
	kadd("TypeScript", "function var let const async await yield import export from as of in instanceof typeof new this class extends super constructor interface type enum implements declare abstract readonly namespace module never unknown any void string number boolean")
	kadd("Java", "package import class interface enum extends implements abstract synchronized throws throw native strictfp transient volatile finally true false null instanceof var record sealed permits non-sealed")
	kadd("Go", "func package import var const type map chan interface struct defer go select fallthrough range iota true false nil make new append cap copy delete len panic recover")
	kadd("Rust", "fn let mut pub crate mod use struct enum impl trait where async await move ref self Self super type const static unsafe dyn match loop for in if else while break continue return true false as Box Option Result Some None Ok Err")
	kadd("PHP", "function class interface trait namespace use as public private protected static abstract final echo print isset empty unset new clone instanceof insteadof yield from match true false null")
	kadd("C#", "namespace using class interface struct record enum delegate event public private protected internal static abstract sealed override virtual async await var dynamic string object bool true false null get set init")
	kadd("Kotlin", "fun val var class object interface data sealed inner companion when in is as typealias suspend override lateinit by constructor init true false null")
	kadd("Scala", "def val var object trait implicit lazy override sealed abstract case match forSome yield true false null")
	kadd("Swift", "func let var class struct enum protocol extension guard defer inout associatedtype typealias actor isolated throwing async await true false nil self Self")
	kadd("Dart", "void var final const late required factory mixin on covariant true false null")
	kadd("Zig", "fn pub const var struct enum union error test comptime export extern packed align asm unreachable true false undefined null")
	kadd("D", "alias mixin invariant scope lazy pure nothrow ref inout immutable shared true false null")
	kadd("shell", "if then else elif fi for while until do done case esac in function select time coproc return break continue true false shift export local readonly declare typeset alias eval exec source trap wait jobs fg bg pwd test echo printf read cd mkdir rmdir rm cp mv cat")
	kadd("python", "and as assert async await break class continue def del elif else except False finally for from global if import in is lambda None nonlocal not or pass raise return True try while with yield match case type")
	kadd("ruby", "alias and begin break case class def defined? do else elsif end ensure false for if in module next nil not or redo rescue retry return self super then true undef unless until when while yield")
	kadd("perl", "if unless elsif else while until for foreach do done given when default sub my our local state package use require no next last redo goto return die warn eval bless shift unshift push pop split join map grep sort keys values each defined undef exists delete ref true false")
	kadd("awk", "BEGIN END if else while do for in break continue next nextfile delete exit return print printf getline function")
	kadd("lua", "and break do else elseif end false for function goto if in local nil not or repeat return then true until while")
	kadd("r", "if else repeat while function for in next break TRUE FALSE NULL NA Inf NaN")
	kadd("tcl", "if else elseif then for foreach while switch proc return break continue set unset lappend lindex lrange concat expr puts gets open close source package namespace")
	kadd("sql", "select insert update delete from where join inner left right full outer on group by order having limit offset as and or not null is in like between exists case when then else end create alter drop table index view into values set distinct union all primary key foreign references default constraint")
	kadd("make", "ifeq ifneq ifdef ifndef else endif include define endef export unexport override private vpath")
	kadd("cmake", "if else elseif endif foreach endforeach while endwhile function endfunction macro endmacro set unset list string math file include option project add_executable add_library target_link_libraries message return break continue")
	kadd("docker", "FROM RUN CMD LABEL MAINTAINER EXPOSE ENV ADD COPY ENTRYPOINT VOLUME USER WORKDIR ARG ONBUILD STOPSIGNAL HEALTHCHECK SHELL AS")
	kadd("nix", "let in rec with inherit import if then else assert abort throw builtins true false null")
	kadd("haskell", "module where import qualified as hiding data type class instance deriving newtype do of let in if then else case infix infixl infixr foreign default")
	kadd("lisp", "defun defmacro defvar defparameter defun lambda if when unless cond case let let* flet labels loop progn quote setq setf funcall apply and or not nil t")
	kadd("erlang", "after and andalso band begin bnot bor bsl bsr bxor case catch cond div end fun if let not of or orelse receive rem try when xor")
	kadd("elixir", "def defp defmodule defmacro defmacrop defstruct defprotocol defimpl defdelegate defguard alias import require use if unless cond case with for try rescue catch after else end fn do true false nil")
	kadd("fortran", "program end subroutine function module use implicit none integer real character logical complex parameter allocatable dimension intent in out inout if then else elseif endif do enddo while select case call return stop continue")
	kadd("vim", "if else elseif endif for endfor while endwhile function endfunction return let unlet set setlocal noremap nnoremap inoremap vnoremap syntax highlight command autocmd augroup")
	kadd("proto", "syntax package import option message enum service rpc returns repeated optional required oneof map reserved true false")
	kadd("graphql", "type interface union enum input extend schema scalar query mutation subscription fragment on true false null implements")
	kadd("asm", "section global extern db dw dd dq resb resw resd resq equ times jmp je jne jz jnz call ret push pop mov add sub mul div cmp and or xor not lea nop")
}

function jesc(s) {
	gsub(/\\/, "\\\\", s)
	gsub(/"/, "\\\"", s)
	return s
}

function fam_of(lang,    g) {
	if (lang == "")
		return "generic"
	if (lang in FAM)
		return FAM[lang]
	g = LGROUP[lang]
	if (g != "" && g in FAM)
		return FAM[g]
	if (g != "" && g != lang && (g in FAM))
		return FAM[g]
	return "generic"
}

function fence_lang(info,    s) {
	s = info
	sub(/^[ \t{]+/, "", s)
	sub(/[ \t}].*/, "", s)
	if (s == "")
		return ""
	if (tolower(s) in FENCE)
		return FENCE[tolower(s)]
	if (s in FAM || s in LGROUP)
		return s
	if (tolower(s) == "text" || tolower(s) == "plain")
		return "Text"
	return s
}

function hl_src(text, lang,    fam) {
	fam = fam_of(lang)
	if (fam == "plain" || fam == "markdown")
		return esc(text)
	if (fam == "xml")
		return hl_xml(text)
	if (fam == "css")
		return hl_css(text)
	if (fam == "json")
		return hl_json(text)
	if (fam == "diff")
		return hl_diff(text)
	if (fam == "lisp")
		return hl_linec(text, lang, fam, ";")
	if (fam == "sql")
		return hl_sql(text, lang)
	if (fam == "lua")
		return hl_lua(text)
	if (fam == "haskell")
		return hl_linec(text, lang, fam, "--")
	if (fam == "erlang")
		return hl_linec(text, lang, fam, "%")
	if (fam == "tex")
		return hl_linec(text, lang, fam, "%")
	if (fam == "vim")
		return hl_vim(text)
	if (fam == "fortran")
		return hl_linec(text, lang, fam, "!")
	if (fam == "asm")
		return hl_linec(text, lang, fam, ";")
	if (fam == "clike")
		return hl_clike(text, lang, fam)
	if (fam == "python")
		return hl_python(text, lang)
	if (fam == "elixir")
		return hl_hash(text, lang, fam)
	return hl_hash(text, lang, fam)
}

function take_word(text, i,    j, n, c) {
	n = length(text)
	j = i
	while (j <= n) {
		c = substr(text, j, 1)
		if (c !~ /[A-Za-z0-9_]/)
			break
		j++
	}
	return j - i
}

function take_num(text, i,    j, n, c, dot) {
	n = length(text)
	j = i
	dot = 0
	if (substr(text, i, 2) == "0x" || substr(text, i, 2) == "0X") {
		j = i + 2
		while (j <= n && substr(text, j, 1) ~ /[0-9A-Fa-f_]/)
			j++
		return j - i
	}
	while (j <= n) {
		c = substr(text, j, 1)
		if (c ~ /[0-9_]/)
			j++
		else if (c == "." && dot == 0) {
			dot = 1
			j++
		} else if ((c == "e" || c == "E") && j < n) {
			j++
			c = substr(text, j, 1)
			if (c == "+" || c == "-")
				j++
			while (j <= n && substr(text, j, 1) ~ /[0-9]/)
				j++
			break
		} else
			break
	}
	return j - i
}

function hl_string(text, i, q,    j, n, c, escst) {
	n = length(text)
	j = i + 1
	escst = 0
	while (j <= n) {
		c = substr(text, j, 1)
		if (escst) {
			escst = 0
			j++
			continue
		}
		if (c == "\\") {
			escst = 1
			j++
			continue
		}
		if (c == q) {
			j++
			break
		}
		j++
	}
	return j - i
}

function hl_hash(text, lang, fam,    i, n, c, out, wlen, word, q, nxt, lnstart) {
	n = length(text)
	i = 1
	out = ""
	lnstart = 1
	while (i <= n) {
		c = substr(text, i, 1)
		if (c == "\n") {
			out = out c
			i++
			lnstart = 1
			continue
		}
		if (c ~ /[ \t]/) {
			out = out c
			i++
			continue
		}
		if (c == "#" && (fam != "elixir" || substr(text, i, 2) != "#{")) {
			wlen = n - i + 1
			nxt = index(substr(text, i), "\n")
			if (nxt > 0)
				wlen = nxt - 1
			out = out sp("c", substr(text, i, wlen))
			i += wlen
			lnstart = 0
			continue
		}
		if (c == "\"" || c == "'") {
			wlen = hl_string(text, i, c)
			out = out sp("s", substr(text, i, wlen))
			i += wlen
			lnstart = 0
			continue
		}
		if (c == "`" && fam == "shell") {
			wlen = hl_string(text, i, "`")
			out = out sp("s", substr(text, i, wlen))
			i += wlen
			lnstart = 0
			continue
		}
		if (c ~ /[0-9]/) {
			wlen = take_num(text, i)
			out = out sp("n", substr(text, i, wlen))
			i += wlen
			lnstart = 0
			continue
		}
		if (c == "$" && (fam == "shell" || fam == "perl")) {
			wlen = 1
			if (substr(text, i + 1, 1) ~ /[A-Za-z_0-9{?!@*#$-]/) {
				if (substr(text, i + 1, 1) == "{") {
					nxt = index(substr(text, i), "}")
					wlen = (nxt > 0) ? nxt : 2
				} else
					wlen = 1 + take_word(text, i + 1)
			}
			out = out sp("b", substr(text, i, wlen))
			i += wlen
			lnstart = 0
			continue
		}
		if (c ~ /[A-Za-z_]/) {
			wlen = take_word(text, i)
			word = substr(text, i, wlen)
			if (iskw(lang, fam, word))
				out = out sp("k", word)
			else if ((fam == "yaml" || fam == "toml" || fam == "ini") && \
				substr(text, i + wlen, 1) == ":")
				out = out sp("a", word)
			else if (substr(text, i + wlen, 1) == "(")
				out = out sp("f", word)
			else
				out = out esc(word)
			i += wlen
			lnstart = 0
			continue
		}
		out = out esc(c)
		i++
		lnstart = 0
	}
	return out
}

function hl_clike(text, lang, fam,    i, n, c, out, wlen, word, nxt, two) {
	n = length(text)
	i = 1
	out = ""
	while (i <= n) {
		c = substr(text, i, 1)
		two = substr(text, i, 2)
		if (c == "\n" || c ~ /[ \t]/) {
			out = out c
			i++
			continue
		}
		if (two == "//") {
			nxt = index(substr(text, i), "\n")
			wlen = (nxt > 0) ? nxt - 1 : n - i + 1
			out = out sp("c", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (two == "/*") {
			nxt = index(substr(text, i + 2), "*/")
			wlen = (nxt > 0) ? nxt + 3 : n - i + 1
			out = out sp("c", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c == "#" && (lang == "C" || lang == "C++" || lang == "Objective-C")) {
			nxt = index(substr(text, i), "\n")
			wlen = (nxt > 0) ? nxt - 1 : n - i + 1
			out = out sp("p", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c == "'" && lang == "Rust") {
			if (substr(text, i + 1, 1) ~ /[A-Za-z_]/) {
				wlen = 1 + take_word(text, i + 1)
				out = out sp("t", substr(text, i, wlen))
				i += wlen
				continue
			}
			out = out esc(c)
			i++
			continue
		}
		if (c == "\"" || c == "'") {
			wlen = hl_string(text, i, c)
			out = out sp("s", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c == "`" && (lang == "JavaScript" || lang == "TypeScript")) {
			wlen = hl_string(text, i, "`")
			out = out sp("s", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c ~ /[0-9]/) {
			wlen = take_num(text, i)
			out = out sp("n", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c ~ /[A-Za-z_]/) {
			wlen = take_word(text, i)
			word = substr(text, i, wlen)
			if (iskw(lang, fam, word) || iskw(lang, "clike", word))
				out = out sp("k", word)
			else if (word ~ /^[A-Z]/ && lang != "JavaScript" && lang != "TypeScript")
				out = out sp("t", word)
			else if (substr(text, i + wlen, 1) == "(")
				out = out sp("f", word)
			else
				out = out esc(word)
			i += wlen
			continue
		}
		out = out esc(c)
		i++
	}
	return out
}

function hl_python(text, lang,    i, n, c, out, wlen, word, nxt, three) {
	n = length(text)
	i = 1
	out = ""
	while (i <= n) {
		c = substr(text, i, 1)
		three = substr(text, i, 3)
		if (c == "\n" || c ~ /[ \t]/) {
			out = out c
			i++
			continue
		}
		if (c == "#") {
			nxt = index(substr(text, i), "\n")
			wlen = (nxt > 0) ? nxt - 1 : n - i + 1
			out = out sp("c", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (three == "\"\"\"" || three == "'''") {
			nxt = index(substr(text, i + 3), three)
			wlen = (nxt > 0) ? nxt + 5 : n - i + 1
			out = out sp("s", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c == "\"" || c == "'") {
			wlen = hl_string(text, i, c)
			out = out sp("s", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c ~ /[0-9]/) {
			wlen = take_num(text, i)
			out = out sp("n", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c ~ /[A-Za-z_]/) {
			wlen = take_word(text, i)
			word = substr(text, i, wlen)
			if (iskw(lang, "python", word))
				out = out sp("k", word)
			else if (substr(text, i + wlen, 1) == "(")
				out = out sp("f", word)
			else
				out = out esc(word)
			i += wlen
			continue
		}
		out = out esc(c)
		i++
	}
	return out
}

function hl_linec(text, lang, fam, mark,    i, n, c, out, wlen, word, nxt, mlen) {
	n = length(text)
	i = 1
	out = ""
	mlen = length(mark)
	while (i <= n) {
		c = substr(text, i, 1)
		if (c == "\n" || c ~ /[ \t]/) {
			out = out c
			i++
			continue
		}
		if (substr(text, i, mlen) == mark) {
			nxt = index(substr(text, i), "\n")
			wlen = (nxt > 0) ? nxt - 1 : n - i + 1
			out = out sp("c", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (fam == "haskell" && substr(text, i, 2) == "{-") {
			nxt = index(substr(text, i + 2), "-}")
			wlen = (nxt > 0) ? nxt + 3 : n - i + 1
			out = out sp("c", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c == "\"" || c == "'") {
			wlen = hl_string(text, i, c)
			out = out sp("s", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c ~ /[0-9]/) {
			wlen = take_num(text, i)
			out = out sp("n", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c ~ /[A-Za-z_]/) {
			wlen = take_word(text, i)
			word = substr(text, i, wlen)
			if (iskw(lang, fam, word))
				out = out sp("k", word)
			else if (substr(text, i + wlen, 1) == "(")
				out = out sp("f", word)
			else
				out = out esc(word)
			i += wlen
			continue
		}
		out = out esc(c)
		i++
	}
	return out
}

function hl_lua(text,    i, n, c, out, wlen, word, nxt, two) {
	n = length(text)
	i = 1
	out = ""
	while (i <= n) {
		c = substr(text, i, 1)
		two = substr(text, i, 2)
		if (c == "\n" || c ~ /[ \t]/) {
			out = out c
			i++
			continue
		}
		if (substr(text, i, 4) == "--[[") {
			nxt = index(substr(text, i + 4), "]]")
			wlen = (nxt > 0) ? nxt + 5 : n - i + 1
			out = out sp("c", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (two == "--") {
			nxt = index(substr(text, i), "\n")
			wlen = (nxt > 0) ? nxt - 1 : n - i + 1
			out = out sp("c", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c == "\"" || c == "'") {
			wlen = hl_string(text, i, c)
			out = out sp("s", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c ~ /[0-9]/) {
			wlen = take_num(text, i)
			out = out sp("n", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c ~ /[A-Za-z_]/) {
			wlen = take_word(text, i)
			word = substr(text, i, wlen)
			if (iskw("Lua", "lua", word))
				out = out sp("k", word)
			else if (substr(text, i + wlen, 1) == "(")
				out = out sp("f", word)
			else
				out = out esc(word)
			i += wlen
			continue
		}
		out = out esc(c)
		i++
	}
	return out
}

function hl_vim(text) {
	return hl_linec(text, "Vim Script", "vim", "\"")
}

function hl_sql(text, lang,    i, n, c, out, wlen, word, nxt, two, up) {
	n = length(text)
	i = 1
	out = ""
	while (i <= n) {
		c = substr(text, i, 1)
		two = substr(text, i, 2)
		if (c == "\n" || c ~ /[ \t]/) {
			out = out c
			i++
			continue
		}
		if (two == "--") {
			nxt = index(substr(text, i), "\n")
			wlen = (nxt > 0) ? nxt - 1 : n - i + 1
			out = out sp("c", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (two == "/*") {
			nxt = index(substr(text, i + 2), "*/")
			wlen = (nxt > 0) ? nxt + 3 : n - i + 1
			out = out sp("c", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c == "'" || c == "\"") {
			wlen = hl_string(text, i, c)
			out = out sp("s", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c ~ /[0-9]/) {
			wlen = take_num(text, i)
			out = out sp("n", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c ~ /[A-Za-z_]/) {
			wlen = take_word(text, i)
			word = substr(text, i, wlen)
			up = toupper(word)
			if (iskw(lang, "sql", tolower(word)) || iskw(lang, "sql", up))
				out = out sp("k", word)
			else
				out = out esc(word)
			i += wlen
			continue
		}
		out = out esc(c)
		i++
	}
	return out
}

function hl_xml(text,    i, n, c, out, wlen, nxt, two, inattr) {
	n = length(text)
	i = 1
	out = ""
	while (i <= n) {
		c = substr(text, i, 1)
		two = substr(text, i, 2)
		if (substr(text, i, 4) == "<!--") {
			nxt = index(substr(text, i + 4), "-->")
			wlen = (nxt > 0) ? nxt + 6 : n - i + 1
			out = out sp("c", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c == "<") {
			nxt = index(substr(text, i), ">")
			wlen = (nxt > 0) ? nxt : n - i + 1
			out = out hl_tag(substr(text, i, wlen))
			i += wlen
			continue
		}
		out = out esc(c)
		i++
	}
	return out
}

function hl_tag(tag,    i, n, c, out, wlen, word) {
	n = length(tag)
	i = 1
	out = ""
	while (i <= n) {
		c = substr(tag, i, 1)
		if (c ~ /[ \t\n]/) {
			out = out c
			i++
			continue
		}
		if (c == "\"" || c == "'") {
			wlen = hl_string(tag, i, c)
			out = out sp("s", substr(tag, i, wlen))
			i += wlen
			continue
		}
		if (c ~ /[A-Za-z_:]/) {
			wlen = 0
			while (i + wlen <= n && substr(tag, i + wlen, 1) ~ /[A-Za-z0-9_:-]/)
				wlen++
			word = substr(tag, i, wlen)
			if (i == 1 || substr(tag, i - 1, 1) == "<" || substr(tag, i - 1, 1) == "/")
				out = out sp("g", word)
			else
				out = out sp("a", word)
			i += wlen
			continue
		}
		out = out esc(c)
		i++
	}
	return out
}

function hl_css(text,    i, n, c, out, wlen, nxt, two, word) {
	n = length(text)
	i = 1
	out = ""
	while (i <= n) {
		c = substr(text, i, 1)
		two = substr(text, i, 2)
		if (two == "/*") {
			nxt = index(substr(text, i + 2), "*/")
			wlen = (nxt > 0) ? nxt + 3 : n - i + 1
			out = out sp("c", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c == "\"" || c == "'") {
			wlen = hl_string(text, i, c)
			out = out sp("s", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c == "#") {
			wlen = 1
			while (i + wlen <= n && substr(text, i + wlen, 1) ~ /[0-9A-Fa-f]/)
				wlen++
			if (wlen > 1) {
				out = out sp("n", substr(text, i, wlen))
				i += wlen
				continue
			}
		}
		if (c ~ /[A-Za-z_-]/) {
			wlen = 0
			while (i + wlen <= n && substr(text, i + wlen, 1) ~ /[A-Za-z0-9_-]/)
				wlen++
			word = substr(text, i, wlen)
			if (substr(text, i + wlen, 1) == ":")
				out = out sp("a", word)
			else
				out = out sp("g", word)
			i += wlen
			continue
		}
		if (c ~ /[0-9]/) {
			wlen = take_num(text, i)
			out = out sp("n", substr(text, i, wlen))
			i += wlen
			continue
		}
		out = out esc(c)
		i++
	}
	return out
}

function hl_json(text,    i, n, c, out, wlen, word) {
	n = length(text)
	i = 1
	out = ""
	while (i <= n) {
		c = substr(text, i, 1)
		if (c == "\n" || c ~ /[ \t]/) {
			out = out c
			i++
			continue
		}
		if (c == "\"") {
			wlen = hl_string(text, i, "\"")
			word = substr(text, i, wlen)
			if (looking_colon(text, i + wlen))
				out = out sp("a", word)
			else
				out = out sp("s", word)
			i += wlen
			continue
		}
		if (c ~ /[0-9-]/ && (c != "-" || substr(text, i + 1, 1) ~ /[0-9]/)) {
			if (c == "-") {
				wlen = 1 + take_num(text, i + 1)
			} else
				wlen = take_num(text, i)
			out = out sp("n", substr(text, i, wlen))
			i += wlen
			continue
		}
		if (c ~ /[A-Za-z]/) {
			wlen = take_word(text, i)
			word = substr(text, i, wlen)
			if (word == "true" || word == "false" || word == "null")
				out = out sp("k", word)
			else
				out = out esc(word)
			i += wlen
			continue
		}
		out = out esc(c)
		i++
	}
	return out
}

function looking_colon(text, i,    n, c) {
	n = length(text)
	while (i <= n) {
		c = substr(text, i, 1)
		if (c ~ /[ \t\n]/) {
			i++
			continue
		}
		return c == ":"
	}
	return 0
}

function hl_diff(text,    i, n, line, out, nxt, first) {
	n = length(text)
	i = 1
	out = ""
	while (i <= n) {
		nxt = index(substr(text, i), "\n")
		if (nxt > 0) {
			line = substr(text, i, nxt)
			i += nxt
		} else {
			line = substr(text, i)
			i = n + 1
		}
		first = substr(line, 1, 1)
		if (line ~ /^diff / || line ~ /^index / || line ~ /^--- / || line ~ /^\+\+\+ /)
			out = out sp("p", line)
		else if (line ~ /^@@/)
			out = out sp("t", line)
		else if (first == "+")
			out = out sp("s", line)
		else if (first == "-")
			out = out sp("g", line)
		else
			out = out esc(line)
	}
	return out
}

function wrap_hl(html, lang,    label) {
	label = (lang != "") ? lang : "text"
	return "<pre class=\"block git-blob is-hl\" data-lang=\"" esc(lang) \
		"\" aria-label=\"" esc(label) "\"><code>" html "</code></pre>"
}

function md_split(text,    n, i, c, line) {
	n = 0
	line = ""
	for (i = 1; i <= length(text); i++) {
		c = substr(text, i, 1)
		if (c == "\n") {
			n++
			MD[n] = line
			line = ""
		} else if (c != "\r")
			line = line c
	}
	n++
	MD[n] = line
	NMD = n
}

function md_fence_open(line,    s, ticks) {
	s = line
	sub(/^[ \t]*/, "", s)
	if (s !~ /^(```|~~~)/)
		return 0
	ticks = substr(s, 1, 3)
	FENCE_TICKS = ticks
	s = substr(s, 4)
	sub(/^[ \t]+/, "", s)
	FENCE_INFO = s
	return 1
}

function md_fence_close(line,    s) {
	s = line
	sub(/^[ \t]*/, "", s)
	sub(/[ \t]*$/, "", s)
	return s == FENCE_TICKS
}

function md_hr(line,    s) {
	s = line
	sub(/^[ \t]+/, "", s)
	sub(/[ \t]+$/, "", s)
	return s ~ /^(-{3,}|\*{3,}|_{3,})$/
}

function md_heading(line,    s, i) {
	s = line
	sub(/^[ \t]+/, "", s)
	if (s !~ /^#{1,6}[ \t]/)
		return 0
	i = 1
	while (substr(s, i, 1) == "#" && i <= 6)
		i++
	HD_LEVEL = i - 1
	HD_TEXT = substr(s, i)
	sub(/^[ \t]+/, "", HD_TEXT)
	sub(/[ \t]+#*[ \t]*$/, "", HD_TEXT)
	return 1
}

function md_ul(line,    s) {
	s = line
	if (match(s, /^[ \t]*[-*+][ \t]+/)) {
		UL_INDENT = RLENGTH
		UL_TEXT = substr(s, RLENGTH + 1)
		return 1
	}
	return 0
}

function md_ol(line,    s) {
	s = line
	if (match(s, /^[ \t]*[0-9]+\.[ \t]+/)) {
		UL_INDENT = RLENGTH
		UL_TEXT = substr(s, RLENGTH + 1)
		return 1
	}
	return 0
}

function md_quote(line,    s) {
	s = line
	if (match(s, /^[ \t]*>[ \t]?/)) {
		UL_TEXT = substr(s, RLENGTH + 1)
		return 1
	}
	return 0
}

function md_table_row(line,    s) {
	s = line
	sub(/^[ \t]+/, "", s)
	sub(/[ \t]+$/, "", s)
	return s ~ /^\|.*\|$/
}

function md_inline(s,    out, n, i, c, two, nxt, tmp, url, label, clpos, ticks, wlen) {
	out = ""
	n = length(s)
	i = 1
	while (i <= n) {
		c = substr(s, i, 1)
		two = substr(s, i, 2)
		if (c == "`") {
			ticks = 1
			while (i + ticks <= n && substr(s, i + ticks, 1) == "`")
				ticks++
			clpos = index(substr(s, i + ticks), substr("``````", 1, ticks))
			if (clpos > 0) {
				tmp = substr(s, i + ticks, clpos - 1)
				out = out "<code>" esc(tmp) "</code>"
				i = i + ticks + clpos - 1 + ticks
				continue
			}
		}
		if (two == "![") {
			nxt = match(substr(s, i), /^\[[^\]]*\]\([^)]+\)/)
			if (match(substr(s, i), /^!\[[^\]]*\]\([^)]+\)/)) {
				tmp = substr(s, i, RLENGTH)
				label = tmp
				sub(/^!\[/, "", label)
				sub(/\]\([^)]+\)$/, "", label)
				url = tmp
				sub(/^!\[[^\]]*\]\(/, "", url)
				sub(/\)$/, "", url)
				if (url ~ /^https?:\/\//)
					out = out "<img src=\"" esc(url) "\" alt=\"" esc(label) "\">"
				else
					out = out esc(tmp)
				i += RLENGTH
				continue
			}
		}
		if (c == "[" && match(substr(s, i), /^\[[^\]]+\]\([^)]+\)/)) {
			tmp = substr(s, i, RLENGTH)
			label = tmp
			sub(/^\[/, "", label)
			sub(/\]\([^)]+\)$/, "", label)
			url = tmp
			sub(/^\[[^\]]+\]\(/, "", url)
			sub(/\)$/, "", url)
			if (url ~ /^https?:\/\// || url ~ /^\// || url ~ /^\.\.?\//)
				out = out "<a href=\"" esc(url) "\">" md_inline(label) "</a>"
			else
				out = out esc(tmp)
			i += RLENGTH
			continue
		}
		if (two == "**" || two == "__") {
			clpos = index(substr(s, i + 2), two)
			if (clpos > 0) {
				tmp = substr(s, i + 2, clpos - 1)
				out = out "<strong>" md_inline(tmp) "</strong>"
				i = i + 2 + clpos - 1 + 2
				continue
			}
		}
		if (two == "~~") {
			clpos = index(substr(s, i + 2), "~~")
			if (clpos > 0) {
				tmp = substr(s, i + 2, clpos - 1)
				out = out "<del>" md_inline(tmp) "</del>"
				i = i + 2 + clpos - 1 + 2
				continue
			}
		}
		if ((c == "*" || c == "_") && i < n && substr(s, i + 1, 1) !~ /[ \t]/) {
			clpos = index(substr(s, i + 1), c)
			if (clpos > 0 && substr(s, i + clpos + 1, 1) != c) {
				tmp = substr(s, i + 1, clpos - 1)
				if (tmp !~ /\n/) {
					out = out "<em>" md_inline(tmp) "</em>"
					i = i + 1 + clpos
					continue
				}
			}
		}
		if (substr(s, i, 8) == "https://" || substr(s, i, 7) == "http://") {
			wlen = 0
			while (i + wlen <= n && substr(s, i + wlen, 1) !~ /[ \t<>"']/)
				wlen++
			while (wlen > 0 && substr(s, i + wlen - 1, 1) ~ /[.,;:!?)]/)
				wlen--
			url = substr(s, i, wlen)
			out = out "<a href=\"" esc(url) "\">" esc(url) "</a>"
			i += wlen
			continue
		}
		out = out esc(c)
		i++
	}
	return out
}

function md_task(text,    box, rest) {
	if (text ~ /^\[[xX]\][ \t]/) {
		rest = substr(text, 5)
		sub(/^[ \t]+/, "", rest)
		return "<span class=\"task done\">[x]</span> " md_inline(rest)
	}
	if (text ~ /^\[[ ]\][ \t]/) {
		rest = substr(text, 5)
		sub(/^[ \t]+/, "", rest)
		return "<span class=\"task\">[ ]</span> " md_inline(rest)
	}
	return md_inline(text)
}

function md_render(    i, line, buf, lang, html, cells, ncol, j, row, align, a) {
	html = ""
	i = 1
	while (i <= NMD) {
		line = MD[i]
		if (md_fence_open(line)) {
			buf = ""
			i++
			while (i <= NMD && !md_fence_close(MD[i])) {
				if (buf != "")
					buf = buf "\n"
				buf = buf MD[i]
				i++
			}
			if (i <= NMD)
				i++
			lang = fence_lang(FENCE_INFO)
			html = html wrap_hl(hl_src(buf, lang), lang)
			continue
		}
		if (md_hr(line)) {
			html = html "<hr class=\"rule\">\n"
			i++
			continue
		}
		if (md_heading(line)) {
			html = html "<h" (HD_LEVEL + 1) ">" md_inline(HD_TEXT) "</h" (HD_LEVEL + 1) ">\n"
			i++
			continue
		}
		if (md_quote(line)) {
			html = html "<blockquote>"
			while (i <= NMD && md_quote(MD[i])) {
				html = html "<p>" md_inline(UL_TEXT) "</p>"
				i++
			}
			html = html "</blockquote>\n"
			continue
		}
		if (md_table_row(line) && i < NMD && MD[i + 1] ~ /\|[ \t]*:?-+:?[ \t]*\|/) {
			html = html "<table class=\"pkgs md-table\"><thead><tr>"
			row = line
			sub(/^[ \t]*\|/, "", row)
			sub(/\|[ \t]*$/, "", row)
			ncol = split(row, cells, /\|/)
			for (j = 1; j <= ncol; j++) {
				sub(/^[ \t]+/, "", cells[j])
				sub(/[ \t]+$/, "", cells[j])
				html = html "<th>" md_inline(cells[j]) "</th>"
			}
			html = html "</tr></thead><tbody>"
			i += 2
			while (i <= NMD && md_table_row(MD[i])) {
				row = MD[i]
				sub(/^[ \t]*\|/, "", row)
				sub(/\|[ \t]*$/, "", row)
				split(row, cells, /\|/)
				html = html "<tr>"
				for (j = 1; j <= ncol; j++) {
					sub(/^[ \t]+/, "", cells[j])
					sub(/[ \t]+$/, "", cells[j])
					html = html "<td>" md_inline(cells[j]) "</td>"
				}
				html = html "</tr>"
				i++
			}
			html = html "</tbody></table>\n"
			continue
		}
		if (md_ul(line)) {
			html = html "<ul class=\"plain\">"
			while (i <= NMD && md_ul(MD[i])) {
				html = html "<li>" md_task(UL_TEXT) "</li>"
				i++
			}
			html = html "</ul>\n"
			continue
		}
		if (md_ol(line)) {
			html = html "<ol>"
			while (i <= NMD && md_ol(MD[i])) {
				html = html "<li>" md_task(UL_TEXT) "</li>"
				i++
			}
			html = html "</ol>\n"
			continue
		}
		if (line ~ /^(    |\t)/) {
			buf = ""
			while (i <= NMD && MD[i] ~ /^(    |\t)/) {
				row = MD[i]
				if (substr(row, 1, 4) == "    ")
					row = substr(row, 5)
				else if (substr(row, 1, 1) == "\t")
					row = substr(row, 2)
				if (buf != "")
					buf = buf "\n"
				buf = buf row
				i++
			}
			html = html wrap_hl(esc(buf), "")
			continue
		}
		if (line ~ /^[ \t]*$/) {
			i++
			continue
		}
		buf = line
		i++
		if (i <= NMD && MD[i] ~ /^[ \t]*=+[ \t]*$/) {
			html = html "<h2>" md_inline(buf) "</h2>\n"
			i++
			continue
		}
		if (i <= NMD && MD[i] ~ /^[ \t]*-+[ \t]*$/) {
			html = html "<h3>" md_inline(buf) "</h3>\n"
			i++
			continue
		}
		while (i <= NMD && MD[i] !~ /^[ \t]*$/ && !md_fence_open(MD[i]) && !md_heading(MD[i]) && !md_hr(MD[i]) && !md_ul(MD[i]) && !md_ol(MD[i]) && !md_quote(MD[i])) {
			buf = buf " " MD[i]
			i++
		}
		html = html "<p>" md_inline(buf) "</p>\n"
	}
	return html
}

BEGIN {
	load_fams()
	load_kw()
	load_langmap()
}

{
	if (body != "")
		body = body "\n"
	body = body $0
}

END {
	if (mode == "famjson") {
		printf "{"
		n = 0
		for (name in FAM) {
			seen[name] = 1
			if (n++)
				printf ","
			printf "\"%s\":\"%s\"", jesc(name), jesc(FAM[name])
		}
		for (name in LGROUP) {
			if (name in seen)
				continue
			if (n++)
				printf ","
			printf "\"%s\":\"%s\"", jesc(name), jesc(fam_of(name))
			seen[name] = 1
		}
		print "}"
		exit
	}
	if (mode == "highlight") {
		print wrap_hl(hl_src(body, lang), lang)
		exit
	}
	if (mode == "markdown") {
		md_split(body)
		print "<div class=\"md\">"
		printf "%s", md_render()
		print "</div>"
		exit
	}
}
