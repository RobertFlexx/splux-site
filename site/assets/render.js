// Highlight and Markdown for Splux Git. Matches tools/render.awk so
// live/404 pages get the same boxes as the baked HTML.
(function (root) {
	var FAM = {
		Shell: "shell", Bash: "shell", Zsh: "shell", Fish: "shell",
		Nushell: "shell", PowerShell: "shell", Batchfile: "shell",
		"Alpine Abuild": "shell", "Gentoo Ebuild": "shell",
		C: "clike", "C++": "clike", "C#": "clike",
		"Objective-C": "clike", "Objective-C++": "clike",
		Java: "clike", JavaScript: "clike", TypeScript: "clike",
		Go: "clike", Rust: "clike", PHP: "clike", Kotlin: "clike",
		Scala: "clike", Swift: "clike", Dart: "clike", D: "clike",
		Groovy: "clike", Apex: "clike", Vala: "clike", Zig: "clike",
		Carbon: "clike", V: "clike", Nim: "clike", Crystal: "clike",
		Python: "python", Starlark: "python", Cython: "python",
		Snakemake: "python", Ruby: "ruby", Perl: "perl", Raku: "perl",
		Awk: "awk", Lua: "lua", R: "r", Tcl: "tcl",
		SQL: "sql", PLpgSQL: "sql", TSQL: "sql", PLSQL: "sql",
		HTML: "xml", XML: "xml", SVG: "xml", XSLT: "xml", Vue: "xml",
		Svelte: "xml", Astro: "xml", JSX: "xml", TSX: "xml",
		CSS: "css", SCSS: "css", Sass: "css", Less: "css", PostCSS: "css",
		JSON: "json", JSON5: "json", JSONC: "json",
		"JSON with Comments": "json", YAML: "yaml", TOML: "toml", INI: "ini",
		Desktop: "ini", "Git Config": "ini", Makefile: "make", CMake: "cmake",
		Diff: "diff", "Ignore List": "ini", Lisp: "lisp", Scheme: "lisp",
		"Common Lisp": "lisp", "Emacs Lisp": "lisp", Clojure: "lisp",
		Racket: "lisp", Haskell: "haskell", Idris: "haskell",
		Elixir: "elixir", Erlang: "erlang", Fortran: "fortran",
		"Fortran Free Form": "fortran", "Vim Script": "vim",
		"Vim Help File": "vim", Dockerfile: "docker", Nix: "nix",
		"Protocol Buffer": "proto", GraphQL: "graphql",
		TeX: "tex", LaTeX: "tex", BibTeX: "tex",
		Assembly: "asm", "Unix Assembly": "asm",
		Markdown: "markdown", MDX: "markdown", Text: "plain"
	};
	var EXTRA_FAM = {};
	var FENCE = {
		sh: "Shell", bash: "Shell", zsh: "Shell", shell: "Shell",
		js: "JavaScript", javascript: "JavaScript", mjs: "JavaScript",
		cjs: "JavaScript", ts: "TypeScript", typescript: "TypeScript",
		jsx: "JavaScript", tsx: "TypeScript",
		py: "Python", python: "Python", pyi: "Python",
		rb: "Ruby", ruby: "Ruby", pl: "Perl", perl: "Perl",
		lua: "Lua", sql: "SQL", c: "C", h: "C", cpp: "C++", "c++": "C++",
		cc: "C++", cxx: "C++", hpp: "C++", hh: "C++",
		rs: "Rust", rust: "Rust", go: "Go", golang: "Go", java: "Java",
		kt: "Kotlin", kts: "Kotlin", cs: "C#", php: "PHP",
		swift: "Swift", dart: "Dart", zig: "Zig",
		html: "HTML", htm: "HTML", xml: "XML", css: "CSS",
		scss: "SCSS", sass: "Sass", less: "Less", json: "JSON",
		jsonc: "JSONC", yml: "YAML", yaml: "YAML", toml: "TOML",
		md: "Markdown", markdown: "Markdown", mdx: "Markdown",
		awk: "Awk", make: "Makefile", makefile: "Makefile",
		diff: "Diff", patch: "Diff",
		dockerfile: "Dockerfile", docker: "Dockerfile", nix: "Nix",
		cmake: "CMake", r: "R", hs: "Haskell", lisp: "Lisp",
		el: "Emacs Lisp", vim: "Vim Script", ex: "Elixir", exs: "Elixir",
		erl: "Erlang", proto: "Protocol Buffer", graphql: "GraphQL",
		gql: "GraphQL", tex: "TeX", latex: "TeX", ini: "INI",
		cfg: "INI", conf: "INI", s: "Assembly", asm: "Assembly",
		f90: "Fortran", f95: "Fortran", vue: "Vue", svg: "SVG"
	};
	var KW = {};

	function addkw(key, words) {
		var a = words.split(/\s+/);
		KW[key] = KW[key] || {};
		for (var i = 0; i < a.length; i++)
			if (a[i])
				KW[key][a[i]] = 1;
	}

	addkw("clike", "if else for while do switch case default break continue return goto sizeof typedef struct union enum const static extern volatile void int char short long float double signed unsigned bool true false NULL nullptr this new delete try catch throw class public private protected namespace using template typename virtual override final inline explicit operator");
	addkw("JavaScript", "function var let const async await yield import export from as of in instanceof typeof new this class extends super constructor null true false undefined");
	addkw("TypeScript", "function var let const async await yield import export from as of in instanceof typeof new this class extends super constructor interface type enum implements declare abstract readonly never unknown any void string number boolean");
	addkw("Java", "package import class interface enum extends implements abstract synchronized throws throw finally true false null instanceof var record");
	addkw("Go", "func package import var const type map chan interface struct defer go select range iota true false nil make new append len");
	addkw("Rust", "fn let mut pub crate mod use struct enum impl trait where async await move ref self Self super type const static unsafe match loop true false as Some None Ok Err");
	addkw("PHP", "function class interface trait namespace use as public private protected static abstract final echo print new clone true false null");
	addkw("C#", "namespace using class interface struct record enum public private protected internal static abstract override virtual async await var string object bool true false null");
	addkw("shell", "if then else elif fi for while until do done case esac in function select return break continue true false shift export local readonly declare alias eval exec source trap wait pwd test echo printf read cd mkdir rmdir rm cp mv cat");
	addkw("python", "and as assert async await break class continue def del elif else except False finally for from global if import in is lambda None nonlocal not or pass raise return True try while with yield match case");
	addkw("ruby", "alias and begin break case class def do else elsif end ensure false for if in module next nil not or redo rescue retry return self super then true undef unless until when while yield");
	addkw("perl", "if unless elsif else while until for foreach sub my our local package use require next last redo return die warn eval shift push pop split join map grep");
	addkw("awk", "BEGIN END if else while do for in break continue next nextfile delete exit return print printf getline function");
	addkw("lua", "and break do else elseif end false for function goto if in local nil not or repeat return then true until while");
	addkw("sql", "select insert update delete from where join inner left right full outer on group by order having limit offset as and or not null is in like between exists case when then else end create alter drop table index view into values set distinct union all");
	addkw("make", "ifeq ifneq ifdef ifndef else endif include define endef export override");
	addkw("cmake", "if else elseif endif foreach endforeach while function endfunction macro set list string file include option project add_executable add_library message");
	addkw("docker", "FROM RUN CMD LABEL EXPOSE ENV ADD COPY ENTRYPOINT VOLUME USER WORKDIR ARG ONBUILD HEALTHCHECK SHELL AS");
	addkw("nix", "let in rec with inherit import if then else assert true false null");
	addkw("haskell", "module where import qualified as hiding data type class instance deriving do of let in if then else case");
	addkw("lisp", "defun defmacro defvar lambda if when unless cond case let loop progn quote setq setf and or not nil t");
	addkw("elixir", "def defp defmodule defmacro alias import require use if unless cond case with for try rescue catch after else end fn do true false nil");
	addkw("erlang", "after and andalso begin case catch end fun if not of or orelse receive try when");
	addkw("vim", "if else elseif endif for endfor while endwhile function endfunction return let set noremap syntax highlight command autocmd");
	addkw("r", "if else repeat while function for in next break TRUE FALSE NULL NA Inf NaN");
	addkw("tcl", "if else elseif then for foreach while switch proc return break continue set puts source");
	addkw("proto", "syntax package import option message enum service rpc returns repeated optional required true false");
	addkw("graphql", "type interface union enum input extend schema scalar query mutation subscription fragment on true false null");
	addkw("asm", "section global extern jmp call ret push pop mov add sub mul div cmp and or xor lea nop");
	addkw("fortran", "program end subroutine function module use implicit none integer real character logical if then else endif do enddo call return");

	function esc(s) {
		return String(s == null ? "" : s)
			.replace(/&/g, "&amp;")
			.replace(/</g, "&lt;")
			.replace(/>/g, "&gt;")
			.replace(/"/g, "&quot;");
	}

	function sp(cls, s) {
		return s ? "<span class=\"" + cls + "\">" + esc(s) + "</span>" : "";
	}

	function famOf(lang) {
		if (!lang)
			return "generic";
		if (FAM[lang])
			return FAM[lang];
		if (EXTRA_FAM[lang])
			return EXTRA_FAM[lang];
		if (FENCE[String(lang).toLowerCase()])
			return famOf(FENCE[String(lang).toLowerCase()]);
		return "generic";
	}

	function setFams(obj) {
		EXTRA_FAM = obj || {};
	}

	function iskw(lang, fam, w) {
		return (KW[lang] && KW[lang][w]) || (KW[fam] && KW[fam][w]);
	}

	function takeWord(text, i) {
		var j = i;
		while (j < text.length && /[A-Za-z0-9_]/.test(text.charAt(j)))
			j++;
		return j - i;
	}

	function takeNum(text, i) {
		var j = i;
		if (text.slice(i, i + 2).toLowerCase() === "0x") {
			j = i + 2;
			while (j < text.length && /[0-9A-Fa-f_]/.test(text.charAt(j)))
				j++;
			return j - i;
		}
		var dot = false;
		while (j < text.length) {
			var c = text.charAt(j);
			if (/[0-9_]/.test(c))
				j++;
			else if (c === "." && !dot) {
				dot = true;
				j++;
			} else
				break;
		}
		return j - i || 1;
	}

	function takeString(text, i, q) {
		var j = i + 1;
		var escst = false;
		while (j < text.length) {
			var c = text.charAt(j);
			if (escst) {
				escst = false;
				j++;
				continue;
			}
			if (c === "\\") {
				escst = true;
				j++;
				continue;
			}
			j++;
			if (c === q)
				break;
		}
		return j - i;
	}

	function lineComment(text, i) {
		var n = text.indexOf("\n", i);
		return n === -1 ? text.length - i : n - i;
	}

	function hlHash(text, lang, fam) {
		var i = 0;
		var n = text.length;
		var out = "";
		while (i < n) {
			var c = text.charAt(i);
			if (c === "\n" || /[ \t]/.test(c)) {
				out += c;
				i++;
				continue;
			}
			if (c === "#" && !(fam === "elixir" && text.slice(i, i + 2) === "#{")) {
				var w = lineComment(text, i);
				out += sp("c", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (c === "\"" || c === "'" || (c === "`" && fam === "shell")) {
				w = takeString(text, i, c);
				out += sp("s", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (/[0-9]/.test(c)) {
				w = takeNum(text, i);
				out += sp("n", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (c === "$" && (fam === "shell" || fam === "perl")) {
				w = 1;
				if (text.charAt(i + 1) === "{") {
					var brace = text.indexOf("}", i);
					w = brace === -1 ? 2 : brace - i + 1;
				} else if (/[A-Za-z_0-9?!@*]/.test(text.charAt(i + 1)))
					w = 1 + takeWord(text, i + 1);
				out += sp("b", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (/[A-Za-z_]/.test(c)) {
				w = takeWord(text, i);
				var word = text.slice(i, i + w);
				if (iskw(lang, fam, word))
					out += sp("k", word);
				else if ((fam === "yaml" || fam === "toml" || fam === "ini") &&
					text.charAt(i + w) === ":")
					out += sp("a", word);
				else if (text.charAt(i + w) === "(")
					out += sp("f", word);
				else
					out += esc(word);
				i += w;
				continue;
			}
			out += esc(c);
			i++;
		}
		return out;
	}

	function hlClike(text, lang, fam) {
		var i = 0;
		var n = text.length;
		var out = "";
		while (i < n) {
			var c = text.charAt(i);
			var two = text.slice(i, i + 2);
			if (c === "\n" || /[ \t]/.test(c)) {
				out += c;
				i++;
				continue;
			}
			if (two === "//") {
				var w = lineComment(text, i);
				out += sp("c", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (two === "/*") {
				var end = text.indexOf("*/", i + 2);
				w = end === -1 ? n - i : end - i + 2;
				out += sp("c", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (c === "#" && (lang === "C" || lang === "C++" ||
				lang === "Objective-C" || lang === "Objective-C++")) {
				w = lineComment(text, i);
				out += sp("p", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (c === "'" && lang === "Rust") {
				if (/[A-Za-z_]/.test(text.charAt(i + 1))) {
					w = 1 + takeWord(text, i + 1);
					out += sp("t", text.slice(i, i + w));
					i += w;
					continue;
				}
				out += esc(c);
				i++;
				continue;
			}
			if (c === "\"" || c === "'" || (c === "`" && (lang === "JavaScript" || lang === "TypeScript"))) {
				w = takeString(text, i, c);
				out += sp("s", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (/[0-9]/.test(c)) {
				w = takeNum(text, i);
				out += sp("n", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (/[A-Za-z_]/.test(c)) {
				w = takeWord(text, i);
				var word = text.slice(i, i + w);
				if (iskw(lang, fam, word) || iskw(lang, "clike", word))
					out += sp("k", word);
				else if (/^[A-Z]/.test(word) && lang !== "JavaScript" && lang !== "TypeScript")
					out += sp("t", word);
				else if (text.charAt(i + w) === "(")
					out += sp("f", word);
				else
					out += esc(word);
				i += w;
				continue;
			}
			out += esc(c);
			i++;
		}
		return out;
	}

	function hlPython(text, lang) {
		var i = 0;
		var n = text.length;
		var out = "";
		while (i < n) {
			var c = text.charAt(i);
			var three = text.slice(i, i + 3);
			if (c === "\n" || /[ \t]/.test(c)) {
				out += c;
				i++;
				continue;
			}
			if (c === "#") {
				var w = lineComment(text, i);
				out += sp("c", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (three === "\"\"\"" || three === "'''") {
				var end = text.indexOf(three, i + 3);
				w = end === -1 ? n - i : end - i + 3;
				out += sp("s", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (c === "\"" || c === "'") {
				w = takeString(text, i, c);
				out += sp("s", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (/[0-9]/.test(c)) {
				w = takeNum(text, i);
				out += sp("n", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (/[A-Za-z_]/.test(c)) {
				w = takeWord(text, i);
				var word = text.slice(i, i + w);
				if (iskw(lang, "python", word))
					out += sp("k", word);
				else if (text.charAt(i + w) === "(")
					out += sp("f", word);
				else
					out += esc(word);
				i += w;
				continue;
			}
			out += esc(c);
			i++;
		}
		return out;
	}

	function hlLinec(text, lang, fam, mark) {
		var i = 0;
		var n = text.length;
		var out = "";
		while (i < n) {
			var c = text.charAt(i);
			if (c === "\n" || /[ \t]/.test(c)) {
				out += c;
				i++;
				continue;
			}
			if (text.slice(i, i + mark.length) === mark) {
				var w = lineComment(text, i);
				out += sp("c", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (c === "\"" || c === "'") {
				w = takeString(text, i, c);
				out += sp("s", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (/[0-9]/.test(c)) {
				w = takeNum(text, i);
				out += sp("n", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (/[A-Za-z_]/.test(c)) {
				w = takeWord(text, i);
				var word = text.slice(i, i + w);
				if (iskw(lang, fam, word))
					out += sp("k", word);
				else if (text.charAt(i + w) === "(")
					out += sp("f", word);
				else
					out += esc(word);
				i += w;
				continue;
			}
			out += esc(c);
			i++;
		}
		return out;
	}

	function hlXml(text) {
		var i = 0;
		var n = text.length;
		var out = "";
		while (i < n) {
			if (text.slice(i, i + 4) === "<!--") {
				var end = text.indexOf("-->", i + 4);
				var w = end === -1 ? n - i : end - i + 3;
				out += sp("c", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (text.charAt(i) === "<") {
				end = text.indexOf(">", i);
				w = end === -1 ? n - i : end - i + 1;
				out += hlTag(text.slice(i, i + w));
				i += w;
				continue;
			}
			out += esc(text.charAt(i));
			i++;
		}
		return out;
	}

	function hlTag(tag) {
		var i = 0;
		var n = tag.length;
		var out = "";
		while (i < n) {
			var c = tag.charAt(i);
			if (/[ \t\n]/.test(c)) {
				out += c;
				i++;
				continue;
			}
			if (c === "\"" || c === "'") {
				var w = takeString(tag, i, c);
				out += sp("s", tag.slice(i, i + w));
				i += w;
				continue;
			}
			if (/[A-Za-z_:]/.test(c)) {
				w = 0;
				while (i + w < n && /[A-Za-z0-9_:-]/.test(tag.charAt(i + w)))
					w++;
				var word = tag.slice(i, i + w);
				if (i === 0 || tag.charAt(i - 1) === "<" || tag.charAt(i - 1) === "/")
					out += sp("g", word);
				else
					out += sp("a", word);
				i += w;
				continue;
			}
			out += esc(c);
			i++;
		}
		return out;
	}

	function hlCss(text) {
		var i = 0;
		var n = text.length;
		var out = "";
		while (i < n) {
			if (text.slice(i, i + 2) === "/*") {
				var end = text.indexOf("*/", i + 2);
				var w = end === -1 ? n - i : end - i + 2;
				out += sp("c", text.slice(i, i + w));
				i += w;
				continue;
			}
			var c = text.charAt(i);
			if (c === "\"" || c === "'") {
				w = takeString(text, i, c);
				out += sp("s", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (/[A-Za-z_-]/.test(c)) {
				w = 0;
				while (i + w < n && /[A-Za-z0-9_-]/.test(text.charAt(i + w)))
					w++;
				var word = text.slice(i, i + w);
				out += sp(text.charAt(i + w) === ":" ? "a" : "g", word);
				i += w;
				continue;
			}
			if (/[0-9]/.test(c)) {
				w = takeNum(text, i);
				out += sp("n", text.slice(i, i + w));
				i += w;
				continue;
			}
			out += esc(c);
			i++;
		}
		return out;
	}

	function hlJson(text) {
		var i = 0;
		var n = text.length;
		var out = "";
		while (i < n) {
			var c = text.charAt(i);
			if (c === "\n" || /[ \t]/.test(c)) {
				out += c;
				i++;
				continue;
			}
			if (c === "\"") {
				var w = takeString(text, i, "\"");
				var j = i + w;
				while (j < n && /[ \t\n]/.test(text.charAt(j)))
					j++;
				out += sp(text.charAt(j) === ":" ? "a" : "s", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (/[0-9-]/.test(c)) {
				w = c === "-" ? 1 + takeNum(text, i + 1) : takeNum(text, i);
				out += sp("n", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (/[A-Za-z]/.test(c)) {
				w = takeWord(text, i);
				var word = text.slice(i, i + w);
				out += (word === "true" || word === "false" || word === "null")
					? sp("k", word) : esc(word);
				i += w;
				continue;
			}
			out += esc(c);
			i++;
		}
		return out;
	}

	function hlDiff(text) {
		var lines = text.split("\n");
		var out = [];
		for (var i = 0; i < lines.length; i++) {
			var line = lines[i] + (i < lines.length - 1 ? "\n" : "");
			if (/^(diff |index |--- |\+\+\+ )/.test(line))
				out.push(sp("p", line));
			else if (line.charAt(0) === "@")
				out.push(sp("t", line));
			else if (line.charAt(0) === "+")
				out.push(sp("s", line));
			else if (line.charAt(0) === "-")
				out.push(sp("g", line));
			else
				out.push(esc(line));
		}
		return out.join("");
	}

	function hlLua(text) {
		var i = 0;
		var n = text.length;
		var out = "";
		while (i < n) {
			var c = text.charAt(i);
			var two = text.slice(i, i + 2);
			if (c === "\n" || /[ \t]/.test(c)) {
				out += c;
				i++;
				continue;
			}
			if (text.slice(i, i + 4) === "--[[") {
				var end = text.indexOf("]]", i + 4);
				var w = end === -1 ? n - i : end - i + 2;
				out += sp("c", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (two === "--") {
				w = lineComment(text, i);
				out += sp("c", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (c === "\"" || c === "'") {
				w = takeString(text, i, c);
				out += sp("s", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (/[0-9]/.test(c)) {
				w = takeNum(text, i);
				out += sp("n", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (/[A-Za-z_]/.test(c)) {
				w = takeWord(text, i);
				var word = text.slice(i, i + w);
				if (iskw("Lua", "lua", word))
					out += sp("k", word);
				else if (text.charAt(i + w) === "(")
					out += sp("f", word);
				else
					out += esc(word);
				i += w;
				continue;
			}
			out += esc(c);
			i++;
		}
		return out;
	}

	function hlSql(text, lang) {
		var i = 0;
		var n = text.length;
		var out = "";
		while (i < n) {
			var c = text.charAt(i);
			var two = text.slice(i, i + 2);
			if (c === "\n" || /[ \t]/.test(c)) {
				out += c;
				i++;
				continue;
			}
			if (two === "--") {
				var w = lineComment(text, i);
				out += sp("c", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (two === "/*") {
				var end = text.indexOf("*/", i + 2);
				w = end === -1 ? n - i : end - i + 2;
				out += sp("c", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (c === "'" || c === "\"") {
				w = takeString(text, i, c);
				out += sp("s", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (/[0-9]/.test(c)) {
				w = takeNum(text, i);
				out += sp("n", text.slice(i, i + w));
				i += w;
				continue;
			}
			if (/[A-Za-z_]/.test(c)) {
				w = takeWord(text, i);
				var word = text.slice(i, i + w);
				if (iskw(lang, "sql", word.toLowerCase()) || iskw(lang, "sql", word))
					out += sp("k", word);
				else
					out += esc(word);
				i += w;
				continue;
			}
			out += esc(c);
			i++;
		}
		return out;
	}

	function hlSrc(text, lang) {
		var fam = famOf(lang);
		if (fam === "plain" || fam === "markdown")
			return esc(text);
		if (fam === "xml")
			return hlXml(text);
		if (fam === "css")
			return hlCss(text);
		if (fam === "json")
			return hlJson(text);
		if (fam === "diff")
			return hlDiff(text);
		if (fam === "lisp")
			return hlLinec(text, lang, fam, ";");
		if (fam === "sql")
			return hlSql(text, lang);
		if (fam === "lua")
			return hlLua(text);
		if (fam === "haskell")
			return hlLinec(text, lang, fam, "--");
		if (fam === "erlang" || fam === "tex")
			return hlLinec(text, lang, fam, "%");
		if (fam === "vim")
			return hlLinec(text, lang, fam, "\"");
		if (fam === "fortran")
			return hlLinec(text, lang, fam, "!");
		if (fam === "asm")
			return hlLinec(text, lang, fam, ";");
		if (fam === "clike")
			return hlClike(text, lang, fam);
		if (fam === "python")
			return hlPython(text, lang);
		return hlHash(text, lang, fam);
	}

	function wrapHl(inner, lang) {
		var label = lang || "text";
		return "<pre class=\"block git-blob is-hl\" data-lang=\"" +
			esc(lang || "") + "\" aria-label=\"" + esc(label) +
			"\"><code>" + inner + "</code></pre>";
	}

	function fenceLang(info) {
		info = String(info || "").replace(/^[ \t{]+/, "").replace(/[ \t}].*/, "");
		if (!info)
			return "";
		var low = info.toLowerCase();
		if (low === "text" || low === "plain")
			return "Text";
		return FENCE[low] || info;
	}

	function mdInline(s) {
		var out = "";
		var i = 0;
		var n = s.length;
		while (i < n) {
			var c = s.charAt(i);
			var two = s.slice(i, i + 2);
			if (c === "`") {
				var ticks = 1;
				while (s.charAt(i + ticks) === "`")
					ticks++;
				var close = s.indexOf(s.slice(i, i + ticks), i + ticks);
				if (close !== -1) {
					out += "<code>" + esc(s.slice(i + ticks, close)) + "</code>";
					i = close + ticks;
					continue;
				}
			}
			if (two === "![") {
				var m = s.slice(i).match(/^!\[[^\]]*\]\([^)]+\)/);
				if (m) {
					var label = m[0].replace(/^!\[/, "").replace(/\]\([^)]+\)$/, "");
					var url = m[0].replace(/^!\[[^\]]*\]\(/, "").replace(/\)$/, "");
					if (/^https?:\/\//.test(url))
						out += "<img src=\"" + esc(url) + "\" alt=\"" + esc(label) + "\">";
					else
						out += esc(m[0]);
					i += m[0].length;
					continue;
				}
			}
			if (c === "[") {
				m = s.slice(i).match(/^\[[^\]]+\]\([^)]+\)/);
				if (m) {
					label = m[0].replace(/^\[/, "").replace(/\]\([^)]+\)$/, "");
					url = m[0].replace(/^\[[^\]]+\]\(/, "").replace(/\)$/, "");
					if (/^(https?:\/\/|\/|\.\.?\/)/.test(url))
						out += "<a href=\"" + esc(url) + "\">" + mdInline(label) + "</a>";
					else
						out += esc(m[0]);
					i += m[0].length;
					continue;
				}
			}
			if (two === "**" || two === "__") {
				close = s.indexOf(two, i + 2);
				if (close !== -1) {
					out += "<strong>" + mdInline(s.slice(i + 2, close)) + "</strong>";
					i = close + 2;
					continue;
				}
			}
			if (two === "~~") {
				close = s.indexOf("~~", i + 2);
				if (close !== -1) {
					out += "<del>" + mdInline(s.slice(i + 2, close)) + "</del>";
					i = close + 2;
					continue;
				}
			}
			if ((c === "*" || c === "_") && i + 1 < n && !/[ \t]/.test(s.charAt(i + 1))) {
				close = s.indexOf(c, i + 1);
				if (close !== -1 && s.charAt(close + 1) !== c) {
					out += "<em>" + mdInline(s.slice(i + 1, close)) + "</em>";
					i = close + 1;
					continue;
				}
			}
			if (s.slice(i, i + 8) === "https://" || s.slice(i, i + 7) === "http://") {
				w = 0;
				while (i + w < n && !/[ \t<>"']/.test(s.charAt(i + w)))
					w++;
				while (w > 0 && /[.,;:!?)]/.test(s.charAt(i + w - 1)))
					w--;
				url = s.slice(i, i + w);
				out += "<a href=\"" + esc(url) + "\">" + esc(url) + "</a>";
				i += w;
				continue;
			}
			out += esc(c);
			i++;
		}
		return out;
	}

	function mdTask(text) {
		if (/^\[[xX]\]\s/.test(text))
			return "<span class=\"task done\">[x]</span> " + mdInline(text.slice(4).replace(/^\s+/, ""));
		if (/^\[ \]\s/.test(text))
			return "<span class=\"task\">[ ]</span> " + mdInline(text.slice(4).replace(/^\s+/, ""));
		return mdInline(text);
	}

	function markdown(src) {
		var lines = String(src || "").replace(/\r/g, "").split("\n");
		var html = "";
		var i = 0;
		while (i < lines.length) {
			var line = lines[i];
			var fm = line.match(/^[ \t]*(```|~~~)(.*)$/);
			if (fm) {
				var ticks = fm[1];
				var buf = [];
				i++;
				while (i < lines.length && !new RegExp("^[ \\t]*" + ticks.replace(/`/g, "\\`") + "\\s*$").test(lines[i])) {
					buf.push(lines[i]);
					i++;
				}
				if (i < lines.length)
					i++;
				var lang = fenceLang(fm[2]);
				html += wrapHl(hlSrc(buf.join("\n"), lang), lang);
				continue;
			}
			if (/^[ \t]*(-{3,}|\*{3,}|_{3,})[ \t]*$/.test(line)) {
				html += "<hr class=\"rule\">";
				i++;
				continue;
			}
			var hm = line.match(/^[ \t]*(#{1,6})[ \t]+(.*?)[ \t]*#*[ \t]*$/);
			if (hm) {
				var lv = hm[1].length + 1;
				html += "<h" + lv + ">" + mdInline(hm[2]) + "</h" + lv + ">";
				i++;
				continue;
			}
			if (/^[ \t]*>/.test(line)) {
				html += "<blockquote>";
				while (i < lines.length && /^[ \t]*>/.test(lines[i])) {
					html += "<p>" + mdInline(lines[i].replace(/^[ \t]*>[ \t]?/, "")) + "</p>";
					i++;
				}
				html += "</blockquote>";
				continue;
			}
			if (/^[ \t]*\|.*\|[ \t]*$/.test(line) && i + 1 < lines.length &&
				/\|[ \t]*:?-+:?[ \t]*\|/.test(lines[i + 1])) {
				var splitCells = function (row) {
					row = row.replace(/^[ \t]*\|/, "").replace(/\|[ \t]*$/, "");
					return row.split("|").map(function (c) {
						return c.replace(/^[ \t]+|[ \t]+$/g, "");
					});
				};
				var head = splitCells(line);
				html += "<table class=\"pkgs md-table\"><thead><tr>";
				for (var h = 0; h < head.length; h++)
					html += "<th>" + mdInline(head[h]) + "</th>";
				html += "</tr></thead><tbody>";
				i += 2;
				while (i < lines.length && /^[ \t]*\|.*\|[ \t]*$/.test(lines[i])) {
					var cells = splitCells(lines[i]);
					html += "<tr>";
					for (var c = 0; c < head.length; c++)
						html += "<td>" + mdInline(cells[c] || "") + "</td>";
					html += "</tr>";
					i++;
				}
				html += "</tbody></table>";
				continue;
			}
			if (/^[ \t]*[-*+][ \t]+/.test(line)) {
				html += "<ul class=\"plain\">";
				while (i < lines.length && /^[ \t]*[-*+][ \t]+/.test(lines[i])) {
					html += "<li>" + mdTask(lines[i].replace(/^[ \t]*[-*+][ \t]+/, "")) + "</li>";
					i++;
				}
				html += "</ul>";
				continue;
			}
			if (/^[ \t]*[0-9]+\.[ \t]+/.test(line)) {
				html += "<ol>";
				while (i < lines.length && /^[ \t]*[0-9]+\.[ \t]+/.test(lines[i])) {
					html += "<li>" + mdTask(lines[i].replace(/^[ \t]*[0-9]+\.[ \t]+/, "")) + "</li>";
					i++;
				}
				html += "</ol>";
				continue;
			}
			if (/^[ \t]*$/.test(line)) {
				i++;
				continue;
			}
			if (/^(    |\t)/.test(line)) {
				var code = [];
				while (i < lines.length && /^(    |\t)/.test(lines[i])) {
					code.push(lines[i].replace(/^    /, "").replace(/^\t/, ""));
					i++;
				}
				html += wrapHl(esc(code.join("\n")), "");
				continue;
			}
			var para = line;
			i++;
			if (i < lines.length && /^[ \t]*=+[ \t]*$/.test(lines[i])) {
				html += "<h2>" + mdInline(para) + "</h2>";
				i++;
				continue;
			}
			if (i < lines.length && /^[ \t]*-+[ \t]*$/.test(lines[i])) {
				html += "<h3>" + mdInline(para) + "</h3>";
				i++;
				continue;
			}
			while (i < lines.length && !/^[ \t]*$/.test(lines[i]) &&
				!/^[ \t]*(```|~~~|#{1,6}[ \t]|[-*+][ \t]|[0-9]+\.[ \t]|>)/.test(lines[i])) {
				para += " " + lines[i];
				i++;
			}
			html += "<p>" + mdInline(para) + "</p>";
		}
		return "<div class=\"md\">" + html + "</div>";
	}

	function highlight(text, lang) {
		return wrapHl(hlSrc(String(text || ""), lang || ""), lang || "");
	}

	function isMarkdown(lang, path) {
		if (lang === "Markdown" || lang === "MDX")
			return true;
		path = String(path || "");
		return /\.(md|markdown|mdown|mdx)$/i.test(path);
	}

	function langFromPath(path) {
		var base = String(path || "").replace(/^.*\//, "");
		if (!base)
			return "";
		if (/^recipe$/i.test(base))
			return "Shell";
		if (/^(GNU)?Makefile$/i.test(base) || base === "makefile")
			return "Makefile";
		if (/^Dockerfile$/i.test(base))
			return "Dockerfile";
		if (/^CMakeLists\.txt$/i.test(base))
			return "CMake";
		var n = base.lastIndexOf(".");
		if (n <= 0)
			return "";
		var ext = base.slice(n + 1).toLowerCase();
		return FENCE[ext] || "";
	}

	function apply(root) {
		root = root || document;
		var nodes = root.querySelectorAll("pre.git-blob:not(.is-hl)[data-lang]");
		for (var i = 0; i < nodes.length; i++) {
			var pre = nodes[i];
			var lang = pre.getAttribute("data-lang") || "";
			var text = pre.textContent || "";
			pre.outerHTML = highlight(text, lang);
		}
		var md = root.querySelectorAll("[data-md]:not(.md)");
		for (var j = 0; j < md.length; j++) {
			var el = md[j];
			el.outerHTML = markdown(el.textContent || "");
		}
	}

	root.SpluxRender = {
		highlight: highlight,
		markdown: markdown,
		isMarkdown: isMarkdown,
		langOf: famOf,
		langFromPath: langFromPath,
		setFams: setFams,
		apply: apply
	};
})(window);
