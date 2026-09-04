// Live GitHub refresh for Splux Git. Baked HTML stays if this fails.
// New commits, language bars, and account pages update in the browser.
(function () {
	var API = "https://api.github.com";
	var OWNER = "RobertFlexx";
	var ACCEPT = { Accept: "application/vnd.github+json" };
	var REPOS = ["SPS", "sps-core", "sps-extra", "sps-community", "splux-site"];
	var TTL = 120000;
	var COLORS = {};

	var thisScript = document.currentScript ||
		document.querySelector("script[src*=\"git.js\"]");
	var dataRoot = (thisScript && thisScript.getAttribute("data-root")) || "./";
	var gitHost = (thisScript && thisScript.getAttribute("data-git")) ||
		"https://splux.robertflexx.dev/git";
	gitHost = String(gitHost).replace(/\/+$/, "");
	if (dataRoot === "/")
		dataRoot = "/";

	var main = document.getElementById("main");

	function esc(s) {
		return String(s == null ? "" : s)
			.replace(/&/g, "&amp;")
			.replace(/</g, "&lt;")
			.replace(/>/g, "&gt;")
			.replace(/"/g, "&quot;");
	}

	function validLogin(name) {
		return /^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$/.test(name) &&
			name.length <= 39;
	}

	function formatLocal(iso) {
		var d = new Date(iso);
		if (isNaN(d.getTime()))
			return iso;
		try {
			return d.toLocaleString(undefined, {
				year: "numeric",
				month: "short",
				day: "numeric",
				hour: "numeric",
				minute: "2-digit",
				timeZoneName: "short"
			});
		} catch (e) {
			return d.toString();
		}
	}

	function localizeTimes(root) {
		var times = (root || document).querySelectorAll("time[datetime]");
		for (var i = 0; i < times.length; i++) {
			var iso = times[i].getAttribute("datetime");
			if (iso)
				times[i].textContent = formatLocal(iso);
		}
	}

	function dayOf(iso) {
		iso = String(iso || "");
		var n = iso.indexOf("T");
		return n === -1 ? iso : iso.slice(0, n);
	}

	function json(url) {
		return fetch(url, { headers: ACCEPT, cache: "no-store" }).then(function (r) {
			if (!r.ok)
				throw new Error(String(r.status));
			return r.json();
		});
	}

	function cached(key, url) {
		try {
			var raw = sessionStorage.getItem(key);
			if (raw) {
				var o = JSON.parse(raw);
				if (o && (Date.now() - o.t) < TTL)
					return Promise.resolve(o.v);
			}
		} catch (e) {}
		return json(url).then(function (v) {
			try {
				sessionStorage.setItem(key, JSON.stringify({ t: Date.now(), v: v }));
			} catch (e2) {}
			return v;
		});
	}

	function colorsReady() {
		if (Object.keys(COLORS).length)
			return Promise.resolve(COLORS);
		return Promise.all([
			fetch(dataRoot + "data/linguist-colors.json", { cache: "force-cache" })
				.then(function (r) { return r.ok ? r.json() : {}; }),
			fetch(dataRoot + "data/linguist-fams.json", { cache: "force-cache" })
				.then(function (r) { return r.ok ? r.json() : {}; })
				.catch(function () { return {}; })
		]).then(function (rows) {
			COLORS = rows[0] || {};
			if (window.SpluxRender && SpluxRender.setFams)
				SpluxRender.setFams(rows[1] || {});
			return COLORS;
		}).catch(function () { return COLORS; });
	}

	function colorOf(name) {
		return COLORS[name] || "#888888";
	}

	function parsePath() {
		var p = location.pathname.replace(/\/index\.html$/, "").replace(/\/+$/, "");
		var parts = p.split("/").filter(Boolean);
		var out = { kind: "", repo: "", user: "", sha: "", path: "" };
		if (parts[0] !== "git")
			return out;
		if (parts.length === 1) {
			out.kind = "index";
			return out;
		}
		if (parts[1] === "users") {
			out.kind = parts.length === 2 ? "users" : "user";
			out.user = parts[2] || "";
			return out;
		}
		out.repo = parts[1];
		if (parts.length === 2) {
			out.kind = "repo";
			return out;
		}
		out.kind = parts[2];
		if (out.kind === "commit")
			out.sha = parts[3] || "";
		else if (out.kind === "tree" || out.kind === "blob")
			out.path = parts.slice(3).join("/");
		else if (out.kind === "lang") {
			if (parts.length === 3)
				out.kind = "langs";
			else
				out.path = parts.slice(3).join("/");
		} else if (out.kind === "tags") {
			if (parts.length > 3) {
				out.kind = "tag";
				out.path = decodeSeg(parts.slice(3).join("/"));
			}
		} else if (out.kind === "releases") {
			if (parts[3] === "latest")
				out.kind = "latest";
			else if (parts[3] === "tag" && parts[4]) {
				out.kind = "release";
				out.path = decodeSeg(parts.slice(4).join("/"));
			}
		}
		return out;
	}

	function pageInfo() {
		var info = {
			kind: (main && main.getAttribute("data-kind")) || "",
			repo: (main && main.getAttribute("data-repo")) || "",
			user: (main && main.getAttribute("data-user")) || "",
			sha: (main && main.getAttribute("data-sha")) || "",
			path: (main && main.getAttribute("data-path")) || ""
		};
		var missing = document.title.indexOf("404") === 0 ||
			(main && main.querySelector("h2") &&
				main.querySelector("h2").textContent === "404");
		if (!info.kind || missing) {
			var parsed = parsePath();
			if (parsed.kind) {
				info = parsed;
				info.hydrate = missing ? true : info.hydrate;
				if (missing)
					info.hydrate = true;
			}
		}
		return info;
	}

	function showLive() {
		var el = document.getElementById("git-live");
		if (el)
			el.hidden = false;
	}

	function userHref(login) {
		return gitHost + "/users/" + encodeURIComponent(login) + "/";
	}

	function commitHref(repo, sha) {
		return gitHost + "/" + encodeURIComponent(repo) + "/commit/" +
			encodeURIComponent(sha) + "/";
	}

	function decodeSeg(s) {
		s = String(s || "");
		try {
			return decodeURIComponent(s);
		} catch (e) {
			return s;
		}
	}

	function navHtml(repo, here) {
		var r = repoHref(repo);
		var bits = [];
		if (here === "home")
			bits.push(esc(repo));
		else
			bits.push("<a href=\"" + esc(r) + "\">" + esc(repo) + "</a>");
		bits.push(here === "log"
			? "log"
			: "<a href=\"" + esc(r + "log/") + "\">log</a>");
		bits.push(here === "files"
			? "files"
			: "<a href=\"" + esc(r + "tree/") + "\">files</a>");
		bits.push(here === "refs"
			? "refs"
			: "<a href=\"" + esc(r + "refs/") + "\">refs</a>");
		bits.push(here === "tags" || here === "tag"
			? "tags"
			: "<a href=\"" + esc(r + "tags/") + "\">tags</a>");
		bits.push(here === "releases" || here === "release" || here === "latest"
			? "releases"
			: "<a href=\"" + esc(r + "releases/") + "\">releases</a>");
		bits.push(here === "people"
			? "people"
			: "<a href=\"" + esc(r + "people/") + "\">people</a>");
		bits.push(here === "langs" || here === "lang"
			? "languages"
			: "<a href=\"" + esc(r + "lang/") + "\">languages</a>");
		bits.push("<a href=\"https://github.com/" + OWNER + "/" +
			encodeURIComponent(repo) + "\">GitHub</a>");
		if (here === "commit")
			bits.push("commit");
		if (here === "blob")
			bits.push("file");
		if (here === "tag")
			bits.push("tag");
		if (here === "release")
			bits.push("release");
		if (here === "latest")
			bits.push("latest");
		return "<p class=\"git-nav\">" + bits.join(" · ") + "</p>";
	}

	function tagHref(repo, name) {
		return repoHref(repo) + "tags/" + encodeURIComponent(name) + "/";
	}

	function releaseHref(repo, name) {
		return repoHref(repo) + "releases/tag/" + encodeURIComponent(name) + "/";
	}

	function archiveHref(repo, tag, kind) {
		return "https://github.com/" + OWNER + "/" + encodeURIComponent(repo) +
			"/archive/refs/tags/" + encodeURIComponent(tag) + "." + kind;
	}

	function humansize(n) {
		n = Number(n) || 0;
		if (n >= 1073741824)
			return (n / 1073741824).toFixed(1) + " GB";
		if (n >= 1048576) {
			var mb = n / 1048576;
			return (mb >= 10 ? mb.toFixed(0) : mb.toFixed(1)) + " MB";
		}
		if (n >= 1024)
			return (n / 1024).toFixed(0) + " KB";
		if (n > 0)
			return String(n) + " B";
		return "0 B";
	}

	function renderText(text, lang, path) {
		if (window.SpluxRender) {
			if (SpluxRender.isMarkdown(lang, path))
				return SpluxRender.markdown(text);
			return SpluxRender.highlight(text,
				lang || SpluxRender.langFromPath(path) || "");
		}
		return "<pre class=\"block git-blob\">" + esc(text) + "</pre>";
	}

	function sourceArchivesHtml(repo, tag) {
		return "<h3>Source</h3><ul class=\"plain\">" +
			"<li><a href=\"" + esc(archiveHref(repo, tag, "zip")) + "\">" +
			esc(tag) + ".zip</a></li>" +
			"<li><a href=\"" + esc(archiveHref(repo, tag, "tar.gz")) + "\">" +
			esc(tag) + ".tar.gz</a></li></ul>";
	}

	function repoHref(repo) {
		return gitHost + "/" + encodeURIComponent(repo) + "/";
	}

	function slugLang(name) {
		return String(name || "").replace(/[ \/]/g, "-");
	}

	function langHref(repo, name) {
		return repoHref(repo) + "lang/" + encodeURIComponent(slugLang(name)) + "/";
	}

	function peopleHref(repo) {
		return repoHref(repo) + "people/";
	}

	function avatarOf(login, url) {
		if (url && /^https:\/\/(avatars\.githubusercontent\.com\/|github\.com\/)/.test(url))
			return url;
		if (login && validLogin(login))
			return "https://github.com/" + login + ".png?size=48";
		return "";
	}

	function whoHtml(login, name, avatar) {
		var label = login || name || "";
		if (login && validLogin(login)) {
			var av = avatarOf(login, avatar);
			var html = "<a class=\"who\" href=\"" + esc(userHref(login)) + "\">";
			if (av)
				html += "<img class=\"avatar\" src=\"" + esc(av) +
					"\" width=\"24\" height=\"24\" alt=\"\" loading=\"lazy\">";
			html += esc(login) + "</a>";
			return html;
		}
		return esc(label);
	}

	function firstLine(msg) {
		msg = String(msg || "");
		var n = msg.indexOf("\n");
		return n === -1 ? msg : msg.slice(0, n);
	}

	function fromCommit(c, repo) {
		var commit = (c && c.commit) || {};
		var author = (c && c.author) || {};
		var committer = (c && c.committer) || {};
		var login = author.login || committer.login || "";
		return {
			sha: c.sha || "",
			short: (c.sha || "").slice(0, 7),
			iso: (commit.committer && commit.committer.date) ||
				(commit.author && commit.author.date) || "",
			subject: firstLine(commit.message),
			author: (commit.author && commit.author.name) || login,
			login: login,
			avatar: author.avatar_url || committer.avatar_url || "",
			verified: !!(commit.verification && commit.verification.verified),
			repo: repo || ""
		};
	}

	function commitRow(it, opts) {
		opts = opts || {};
		var href = commitHref(it.repo || opts.repo, it.sha);
		var html = "<tr data-sha=\"" + esc(it.sha) + "\" data-login=\"" +
			esc(it.login) + "\" data-repo=\"" + esc(it.repo || opts.repo || "") + "\">";
		html += "<td><a href=\"" + esc(href) + "\"><code>" + esc(it.short) + "</code></a></td>";
		if (opts.showRepo && it.repo)
			html += "<td><a href=\"" + esc(repoHref(it.repo)) + "\">" +
				esc(it.repo) + "</a></td>";
		html += "<td><a href=\"" + esc(href) + "\">" + esc(it.subject) + "</a></td>";
		html += "<td>" + whoHtml(it.login, it.author, it.avatar);
		if (it.verified)
			html += " <span class=\"verified\">verified</span>";
		html += "</td>";
		html += "<td><time datetime=\"" + esc(it.iso) + "\">" +
			esc(dayOf(it.iso)) + "</time></td></tr>";
		return html;
	}

	function paintLangs(root, langs, repo) {
		if (!root || !langs || !langs.length)
			return;
		var total = 0;
		var i;
		for (i = 0; i < langs.length; i++)
			total += langs[i].bytes || 0;
		if (total <= 0)
			return;
		var html = "<div class=\"lang-bar\" role=\"img\" aria-label=\"Languages\">";
		for (i = 0; i < langs.length; i++) {
			var w = Math.round((langs[i].bytes * 1000) / total) / 10;
			if (w <= 0 && langs[i].bytes > 0)
				w = 0.1;
			var href = repo ? langHref(repo, langs[i].name) : "";
			var style = "width:" + w + "%;background:" +
				esc(langs[i].color || colorOf(langs[i].name));
			var title = esc(langs[i].name) + " " + w + "%";
			if (href)
				html += "<a class=\"lang-seg\" href=\"" + esc(href) +
					"\" style=\"" + style + "\" title=\"" + title + "\"></a>";
			else
				html += "<span class=\"lang-seg\" style=\"" + style +
					"\" title=\"" + title + "\"></span>";
		}
		html += "</div><ul class=\"lang-list\">";
		for (i = 0; i < langs.length; i++) {
			var p = Math.round((langs[i].bytes * 1000) / total) / 10;
			var item = "<span class=\"lang-dot\" style=\"background:" +
				esc(langs[i].color || colorOf(langs[i].name)) + "\"></span> " +
				esc(langs[i].name) + " <span class=\"muted\">" + p + "%</span>";
			if (repo)
				html += "<li><a href=\"" + esc(langHref(repo, langs[i].name)) +
					"\">" + item + "</a></li>";
			else
				html += "<li>" + item + "</li>";
		}
		html += "</ul>";
		root.innerHTML = html;
	}

	function langsFromApi(obj) {
		var rows = [];
		var name;
		for (name in obj) {
			if (Object.prototype.hasOwnProperty.call(obj, name))
				rows.push({ name: name, bytes: obj[name], color: colorOf(name) });
		}
		rows.sort(function (a, b) { return b.bytes - a.bytes; });
		return rows;
	}

	function mergeCommitRows(table, items, repo, showRepo) {
		if (!table || !items || !items.length)
			return 0;
		var body = table.tBodies[0] || table;
		var seen = {};
		var existing = body.querySelectorAll("tr[data-sha]");
		var i;
		for (i = 0; i < existing.length; i++)
			seen[existing[i].getAttribute("data-sha")] = true;
		var added = 0;
		var html = "";
		for (i = 0; i < items.length; i++) {
			if (!items[i].sha || seen[items[i].sha])
				continue;
			seen[items[i].sha] = true;
			html += commitRow(items[i], { repo: repo || items[i].repo, showRepo: showRepo });
			added++;
		}
		if (html) {
			body.insertAdjacentHTML("afterbegin", html);
			localizeTimes(body);
		}
		return added;
	}

	function bindFilter() {
		var input = document.getElementById("git-filter");
		if (!input)
			return;
		var table = document.getElementById("git-repos") ||
			document.getElementById("git-people-table") ||
			document.getElementById("git-lang-table") ||
			document.getElementById("git-tag-table") ||
			document.getElementById("git-asset-table") ||
			document.querySelector("table.git-tree") ||
			document.querySelector("table.git-log") ||
			document.querySelector("table.pkgs");
		var list = document.getElementById("git-releases");
		if (!table && !list)
			return;
		function apply() {
			var q = (input.value || "").toLowerCase();
			var i;
			if (table) {
				var rows = table.querySelectorAll("tbody tr");
				for (i = 0; i < rows.length; i++) {
					var hay = rows[i].getAttribute("data-search") ||
						rows[i].textContent || "";
					rows[i].hidden = q !== "" &&
						hay.toLowerCase().indexOf(q) === -1;
				}
			}
			if (list) {
				var arts = list.querySelectorAll("article.release");
				for (i = 0; i < arts.length; i++) {
					var hay2 = arts[i].getAttribute("data-search") ||
						arts[i].textContent || "";
					arts[i].hidden = q !== "" &&
						hay2.toLowerCase().indexOf(q) === -1;
				}
			}
		}
		input.addEventListener("input", apply);
	}

	function fetchCommits(repo, n) {
		n = n || 30;
		return cached("git-commits-" + repo, API + "/repos/" + OWNER + "/" +
			repo + "/commits?per_page=" + n).then(function (list) {
			var out = [];
			for (var i = 0; i < list.length; i++)
				out.push(fromCommit(list[i], repo));
			return out;
		});
	}

	function fetchLangs(repo) {
		return cached("git-langs-" + repo, API + "/repos/" + OWNER + "/" +
			repo + "/languages").then(langsFromApi);
	}

	function fetchRepo(repo) {
		return cached("git-repo-" + repo, API + "/repos/" + OWNER + "/" + repo);
	}

	function fetchUser(login) {
		return cached("git-user-" + login, API + "/users/" + login);
	}

	function fetchContributors(repo) {
		return cached("git-contrib-" + repo, API + "/repos/" + OWNER + "/" +
			repo + "/contributors?per_page=100");
	}

	function peopleRow(it) {
		var search = ((it.login || "") + " " + (it.name || "")).toLowerCase();
		var html = "<tr data-login=\"" + esc(it.login || "") +
			"\" data-search=\"" + esc(search) + "\">";
		html += "<td>" + whoHtml(it.login, it.name, it.avatar) + "</td>";
		html += "<td class=\"muted\">" + esc(String(it.count || "")) + "</td>";
		if (it.sha && it.repo)
			html += "<td><a href=\"" + esc(commitHref(it.repo, it.sha)) + "\">" +
				esc(it.subject || "") + "</a></td>";
		else
			html += "<td>" + esc(it.subject || "") + "</td>";
		if (it.iso)
			html += "<td><time datetime=\"" + esc(it.iso) + "\">" +
				esc(dayOf(it.iso)) + "</time></td>";
		else
			html += "<td></td>";
		return html + "</tr>";
	}

	function mergePeopleRows(table, items) {
		if (!table || !items || !items.length)
			return 0;
		var body = table.tBodies[0] || table;
		var seen = {};
		var existing = body.querySelectorAll("tr[data-login]");
		var i;
		for (i = 0; i < existing.length; i++) {
			var k = existing[i].getAttribute("data-login") ||
				existing[i].textContent;
			if (k)
				seen[k] = true;
		}
		var added = 0;
		var html = "";
		for (i = 0; i < items.length; i++) {
			var key = items[i].login || items[i].name || "";
			if (!key || seen[key])
				continue;
			seen[key] = true;
			html += peopleRow(items[i]);
			added++;
		}
		if (html) {
			body.insertAdjacentHTML("beforeend", html);
			localizeTimes(body);
		}
		return added;
	}

	function refreshPeople(info) {
		if (!knownRepo(info.repo))
			return;
		return fetchContributors(info.repo).then(function (list) {
			if (!list || !list.length)
				return;
			var items = [];
			for (var i = 0; i < list.length; i++) {
				if (!list[i] || list[i].type === "Anonymous")
					continue;
				items.push({
					login: list[i].login || "",
					name: list[i].login || "",
					avatar: list[i].avatar_url || "",
					count: list[i].contributions || "",
					repo: info.repo
				});
			}
			var table = document.getElementById("git-people-table");
			if (table && mergePeopleRows(table, items))
				showLive();
			var strip = document.getElementById("git-people");
			if (strip && items.length && !strip.querySelector(".person")) {
				var html = "";
				for (var j = 0; j < items.length; j++)
					html += "<span class=\"person\">" +
						whoHtml(items[j].login, items[j].name, items[j].avatar) +
						" <span class=\"muted\">" + esc(String(items[j].count)) +
						"</span></span>";
				strip.innerHTML = html;
				showLive();
			}
		});
	}

	function fetchContents(repo, path) {
		var url = API + "/repos/" + OWNER + "/" + repo + "/contents";
		if (path)
			url += "/" + path.split("/").map(encodeURIComponent).join("/");
		return json(url);
	}

	function decodeContent(item) {
		if (!item || item.encoding !== "base64" || !item.content)
			return "";
		try {
			return decodeURIComponent(escape(atob(item.content.replace(/\s/g, ""))));
		} catch (e) {
			try {
				return atob(item.content.replace(/\s/g, ""));
			} catch (e2) {
				return "";
			}
		}
	}

	function paintCommit(info, c) {
		if (!main || !c)
			return;
		var it = fromCommit(c, info.repo);
		var parents = c.parents || [];
		var files = c.files || [];
		var html = navHtml(info.repo, "commit");
		html += "<h2><code>" + esc(it.short) + "</code></h2><hr class=\"rule\">";
		html += "<p>" + esc(it.subject) + "</p>";
		html += "<div class=\"info\">";
		html += "<div class=\"dl-row\"><span class=\"muted\">Author</span><span>" +
			whoHtml(it.login, it.author, it.avatar) +
			(it.verified ? " <span class=\"verified\">verified</span>" : "") +
			"</span></div>";
		html += "<div class=\"dl-row\"><span class=\"muted\">Date</span><span><time datetime=\"" +
			esc(it.iso) + "\">" + esc(formatLocal(it.iso)) + "</time></span></div>";
		html += "<div class=\"dl-row\"><span class=\"muted\">Commit</span><span><code>" +
			esc(it.sha) + "</code></span></div>";
		html += "<div class=\"dl-row\"><span class=\"muted\">GitHub</span><span><a href=\"" +
			esc(c.html_url || "") + "\">mirror</a></span></div></div>";
		html += "<h3>Parents</h3><ul class=\"plain\">";
		for (var i = 0; i < parents.length; i++) {
			html += "<li><a href=\"" + esc(commitHref(info.repo, parents[i].sha)) +
				"\"><code>" + esc((parents[i].sha || "").slice(0, 7)) +
				"</code></a></li>";
		}
		html += "</ul><h3>Files</h3><ul class=\"plain\">";
		for (var j = 0; j < files.length && j < 80; j++) {
			html += "<li>" + esc(files[j].filename || "") +
				" <span class=\"muted\">" + esc(files[j].status || "") +
				"</span></li>";
		}
		html += "</ul>";
		if (c.stats)
			html += "<p class=\"muted\">+" + esc(String(c.stats.additions || 0)) +
				" / -" + esc(String(c.stats.deletions || 0)) + "</p>";
		var patch = "";
		for (var k = 0; k < files.length; k++) {
			if (files[k].patch)
				patch += "diff --git a/" + (files[k].filename || "") +
					" b/" + (files[k].filename || "") + "\n" +
					files[k].patch + "\n";
		}
		if (patch)
			html += "<h3>Diff</h3>" + renderText(patch, "Diff", "commit.diff");
		main.innerHTML = html;
		document.title = it.short + " - " + info.repo + " - Splux Git";
		localizeTimes(main);
	}

	function paintBlob(info, item) {
		if (!main || !item)
			return;
		var html = navHtml(info.repo, "blob");
		html += "<h2>" + esc(info.path) + "</h2><hr class=\"rule\">";
		if (item.html_url)
			html += "<p class=\"muted\"><a href=\"" + esc(item.html_url) +
				"\">GitHub</a></p>";
		if (item.type === "file") {
			var text = decodeContent(item);
			var lang = (window.SpluxRender && SpluxRender.langFromPath(info.path)) || "";
			if (lang)
				html += "<p class=\"lang-badge\">" + esc(lang) + "</p>";
			if (text)
				html += renderText(text, lang, info.path);
			else
				html += "<p>Open the GitHub mirror for this file.</p>";
		} else {
			html += "<p>Not a file.</p>";
		}
		main.innerHTML = html;
		document.title = info.path + " - " + info.repo + " - Splux Git";
	}

	function paintTree(info, list) {
		if (!main || !list)
			return;
		if (!Array.isArray(list)) {
			paintBlob(info, list);
			return;
		}
		var html = navHtml(info.repo, "files");
		html += "<h2>" + esc(info.path || "Files") + "</h2><hr class=\"rule\">";
		html += "<table class=\"pkgs git-tree\"><thead><tr><th></th><th>Name</th><th>Size</th></tr></thead><tbody>";
		for (var i = 0; i < list.length; i++) {
			var it = list[i];
			var kind = it.type === "dir" ? "dir" : "file";
			var href = gitHost + "/" + encodeURIComponent(info.repo) + "/" +
				(kind === "dir" ? "tree/" : "blob/") +
				(it.path || it.name || "") + "/";
			html += "<tr data-search=\"" + esc((it.name || "").toLowerCase()) + "\">";
			html += "<td class=\"muted\">" + kind + "</td>";
			html += "<td><a href=\"" + esc(href) + "\">" + esc(it.name || "") +
				(kind === "dir" ? "/" : "") + "</a></td>";
			html += "<td class=\"muted\">" + esc(it.size ? String(it.size) : "") +
				"</td></tr>";
		}
		html += "</tbody></table>";
		main.innerHTML = html;
		document.title = (info.path || "Files") + " - " + info.repo + " - Splux Git";
	}

	function paintUser(u, commitsHtml) {
		if (!main || !u)
			return;
		var login = u.login || "";
		var html = "<p class=\"git-nav\"><a href=\"" + esc(gitHost + "/") +
			"\">git</a> · <a href=\"" + esc(gitHost + "/users/") +
			"\">people</a></p>";
		html += "<div class=\"profile\" id=\"git-profile\">";
		if (u.avatar_url)
			html += "<img class=\"avatar profile-avatar\" src=\"" +
				esc(u.avatar_url) + "\" width=\"80\" height=\"80\" alt=\"\">";
		html += "<div class=\"profile-body\"><h2>" + esc(login) + "</h2>";
		if (u.name && u.name !== login)
			html += "<p class=\"profile-name\">" + esc(u.name) + "</p>";
		if (u.bio)
			html += "<p>" + esc(u.bio) + "</p>";
		html += "<div class=\"info\">";
		if (u.html_url)
			html += "<div class=\"dl-row\"><span class=\"muted\">GitHub</span><span><a href=\"" +
				esc(u.html_url) + "\">" + esc(login) + "</a></span></div>";
		if (u.company)
			html += "<div class=\"dl-row\"><span class=\"muted\">Company</span><span>" +
				esc(u.company) + "</span></div>";
		if (u.location)
			html += "<div class=\"dl-row\"><span class=\"muted\">Location</span><span>" +
				esc(u.location) + "</span></div>";
		if (u.blog)
			html += "<div class=\"dl-row\"><span class=\"muted\">URL</span><span><a href=\"" +
				esc(u.blog) + "\">" + esc(u.blog) + "</a></span></div>";
		html += "<div class=\"dl-row\"><span class=\"muted\">Public repos</span><span>" +
			esc(String(u.public_repos || 0)) + "</span></div>";
		html += "<div class=\"dl-row\"><span class=\"muted\">Followers</span><span>" +
			esc(String(u.followers || 0)) + "</span></div>";
		html += "</div></div></div>";
		html += "<h3>Commits in Splux trees</h3><div id=\"git-user-log\">" +
			(commitsHtml || "<p class=\"muted\">None in the baked trees yet.</p>") +
			"</div>";
		main.innerHTML = html;
		document.title = login + " - Splux Git";
	}

	function fetchTags(repo) {
		return cached("git-tags-" + repo, API + "/repos/" + OWNER + "/" +
			repo + "/tags?per_page=100");
	}

	function fetchReleases(repo) {
		return cached("git-releases-" + repo, API + "/repos/" + OWNER + "/" +
			repo + "/releases?per_page=100").then(function (list) {
			var out = [];
			for (var i = 0; i < (list || []).length; i++) {
				if (list[i] && !list[i].draft)
					out.push(list[i]);
			}
			return out;
		});
	}

	function fetchLatestRelease(repo) {
		return cached("git-latest-" + repo, API + "/repos/" + OWNER + "/" +
			repo + "/releases/latest");
	}

	function fetchReleaseByTag(repo, tag) {
		return cached("git-rel-" + repo + "-" + tag, API + "/repos/" + OWNER +
			"/" + repo + "/releases/tags/" + encodeURIComponent(tag));
	}

	function tagRow(it, repo, relset) {
		var name = it.name || "";
		var sha = (it.commit && it.commit.sha) || it.sha || "";
		var short = sha.slice(0, 7);
		var hasRel = relset && relset[name];
		var search = name.toLowerCase();
		var html = "<tr data-tag=\"" + esc(name) + "\" data-sha=\"" +
			esc(sha) + "\" data-search=\"" + esc(search) + "\">";
		html += "<td><a href=\"" + esc(tagHref(repo, name)) +
			"\"><code>" + esc(name) + "</code></a></td>";
		html += "<td>";
		if (sha)
			html += "<a href=\"" + esc(commitHref(repo, sha)) +
				"\"><code>" + esc(short) + "</code></a>";
		html += "</td><td></td><td></td><td>";
		if (hasRel)
			html += "<a href=\"" + esc(releaseHref(repo, name)) +
				"\">release</a>";
		html += "</td></tr>";
		return html;
	}

	function mergeTagRows(table, tags, repo, relset) {
		if (!table || !tags || !tags.length)
			return 0;
		var body = table.tBodies[0] || table;
		var seen = {};
		var existing = body.querySelectorAll("tr[data-tag]");
		var i;
		for (i = 0; i < existing.length; i++)
			seen[existing[i].getAttribute("data-tag")] = true;
		var added = 0;
		var html = "";
		for (i = 0; i < tags.length; i++) {
			var name = tags[i] && tags[i].name;
			if (!name || seen[name])
				continue;
			seen[name] = true;
			html += tagRow(tags[i], repo, relset);
			added++;
		}
		if (html) {
			body.insertAdjacentHTML("afterbegin", html);
			localizeTimes(body);
		}
		return added;
	}

	function releaseArticle(rel, repo, latestTag) {
		var tag = rel.tag_name || "";
		var title = rel.name || tag;
		var login = (rel.author && rel.author.login) || "";
		var avatar = (rel.author && rel.author.avatar_url) || "";
		var iso = rel.published_at || rel.created_at || "";
		var search = (tag + " " + title + " " + login).toLowerCase();
		var nassets = (rel.assets && rel.assets.length) || 0;
		var react = (rel.reactions && rel.reactions.total_count) || 0;
		var html = "<article class=\"release\" data-tag=\"" + esc(tag) +
			"\" data-search=\"" + esc(search) + "\">";
		html += "<p class=\"meta\">";
		if (latestTag && tag === latestTag)
			html += "<span class=\"badge latest\">Latest</span> ";
		if (rel.prerelease)
			html += "<span class=\"badge\">Pre-release</span> ";
		if (iso)
			html += "<time datetime=\"" + esc(iso) + "\">" +
				esc(dayOf(iso)) + "</time> ";
		html += whoHtml(login, login, avatar) + "</p>";
		html += "<h3><a href=\"" + esc(releaseHref(repo, tag)) + "\">" +
			esc(title) + "</a></h3>";
		html += "<p class=\"muted\"><a href=\"" + esc(tagHref(repo, tag)) +
			"\"><code>" + esc(tag) + "</code></a>";
		if (nassets)
			html += " · " + nassets + " files";
		if (react)
			html += " · " + react + " reactions";
		html += "</p>";
		if (rel.body) {
			var excerpt = String(rel.body).replace(/\s+/g, " ");
			if (excerpt.length > 400)
				excerpt = excerpt.slice(0, 400) + "...";
			html += "<p class=\"summary\">" + esc(excerpt) + "</p>";
		}
		html += "</article>";
		return html;
	}

	function mergeReleaseList(root, releases, repo, latestTag) {
		if (!root || !releases || !releases.length)
			return 0;
		var seen = {};
		var existing = root.querySelectorAll("article.release[data-tag]");
		var i;
		for (i = 0; i < existing.length; i++)
			seen[existing[i].getAttribute("data-tag")] = true;
		var added = 0;
		var html = "";
		for (i = 0; i < releases.length; i++) {
			var tag = releases[i] && releases[i].tag_name;
			if (!tag || seen[tag])
				continue;
			seen[tag] = true;
			html += releaseArticle(releases[i], repo, latestTag);
			added++;
		}
		if (html) {
			root.insertAdjacentHTML("afterbegin", html);
			localizeTimes(root);
		}
		return added;
	}

	function paintTags(info, tags, releases) {
		if (!main)
			return;
		var relset = {};
		var i;
		for (i = 0; releases && i < releases.length; i++) {
			if (releases[i] && releases[i].tag_name)
				relset[releases[i].tag_name] = true;
		}
		var html = navHtml(info.repo, "tags");
		html += "<h2>Tags</h2><hr class=\"rule\">";
		html += "<p>Every tag in this tree. A tag with a GitHub release links through to that page.</p>";
		html += "<p><label for=\"git-filter\">Filter</label> <input id=\"git-filter\" type=\"search\" placeholder=\"tag\"></p>";
		if (!tags || !tags.length)
			html += "<p class=\"muted\">No tags in this tree.</p>";
		else {
			html += "<table class=\"pkgs git-tags\" id=\"git-tag-table\"><thead><tr><th>Tag</th><th>Commit</th><th>When</th><th>Message</th><th></th></tr></thead><tbody>";
			for (i = 0; i < tags.length; i++)
				html += tagRow(tags[i], info.repo, relset);
			html += "</tbody></table>";
		}
		main.innerHTML = html;
		document.title = "Tags - " + info.repo + " - Splux Git";
		bindFilter();
	}

	function paintTag(info, tagObj, releases) {
		if (!main)
			return;
		var name = info.path || (tagObj && tagObj.name) || "";
		var sha = (tagObj && tagObj.commit && tagObj.commit.sha) ||
			(tagObj && tagObj.sha) || "";
		var rel = null;
		var i;
		for (i = 0; releases && i < releases.length; i++) {
			if (releases[i] && releases[i].tag_name === name) {
				rel = releases[i];
				break;
			}
		}
		var html = navHtml(info.repo, "tag");
		html += "<h2><code>" + esc(name) + "</code></h2><hr class=\"rule\">";
		html += "<div class=\"info\">";
		if (sha)
			html += "<div class=\"dl-row\"><span class=\"muted\">Commit</span><span><a href=\"" +
				esc(commitHref(info.repo, sha)) + "\"><code>" +
				esc(sha.slice(0, 7)) + "</code></a></span></div>";
		if (rel)
			html += "<div class=\"dl-row\"><span class=\"muted\">Release</span><span><a href=\"" +
				esc(releaseHref(info.repo, name)) + "\">" +
				esc(name) + "</a></span></div>";
		html += "<div class=\"dl-row\"><span class=\"muted\">GitHub</span><span><a href=\"https://github.com/" +
			OWNER + "/" + encodeURIComponent(info.repo) + "/releases/tag/" +
			encodeURIComponent(name) + "\">mirror</a></span></div></div>";
		html += sourceArchivesHtml(info.repo, name);
		main.innerHTML = html;
		document.title = name + " - " + info.repo + " - Splux Git";
	}

	function assetsTable(assets) {
		if (!assets || !assets.length)
			return "";
		var html = "<h3>Assets</h3><table class=\"pkgs git-assets\" id=\"git-asset-table\"><thead><tr><th>File</th><th>Size</th><th>Downloads</th></tr></thead><tbody>";
		for (var i = 0; i < assets.length; i++) {
			var a = assets[i];
			html += "<tr data-search=\"" + esc((a.name || "").toLowerCase()) + "\">";
			html += "<td><a href=\"" + esc(a.browser_download_url || "") + "\">" +
				esc(a.name || "") + "</a></td>";
			html += "<td class=\"muted\">" + esc(humansize(a.size)) + "</td>";
			html += "<td class=\"muted\">" + esc(String(a.download_count || 0)) +
				"</td></tr>";
		}
		html += "</tbody></table>";
		return html;
	}

	function paintRelease(info, rel, latestTag, here) {
		if (!main || !rel)
			return;
		var tag = rel.tag_name || info.path || "";
		var title = rel.name || tag;
		var login = (rel.author && rel.author.login) || "";
		var avatar = (rel.author && rel.author.avatar_url) || "";
		var iso = rel.published_at || rel.created_at || "";
		var html = navHtml(info.repo, here || "release");
		html += "<h2>" + esc(title) + "</h2><hr class=\"rule\">";
		html += "<p class=\"meta\">";
		if (latestTag && tag === latestTag)
			html += "<span class=\"badge latest\">Latest</span> ";
		if (rel.prerelease)
			html += "<span class=\"badge\">Pre-release</span> ";
		html += "</p><div class=\"info\">";
		html += "<div class=\"dl-row\"><span class=\"muted\">Tag</span><span><a href=\"" +
			esc(tagHref(info.repo, tag)) + "\"><code>" + esc(tag) +
			"</code></a></span></div>";
		if (iso)
			html += "<div class=\"dl-row\"><span class=\"muted\">Date</span><span><time datetime=\"" +
				esc(iso) + "\">" + esc(formatLocal(iso)) + "</time></span></div>";
		if (login)
			html += "<div class=\"dl-row\"><span class=\"muted\">Author</span><span>" +
				whoHtml(login, login, avatar) + "</span></div>";
		if (rel.assets && rel.assets.length)
			html += "<div class=\"dl-row\"><span class=\"muted\">Files</span><span>" +
				esc(String(rel.assets.length)) + "</span></div>";
		html += "<div class=\"dl-row\"><span class=\"muted\">GitHub</span><span><a href=\"" +
			esc(rel.html_url || ("https://github.com/" + OWNER + "/" +
				info.repo + "/releases/tag/" + encodeURIComponent(tag))) +
			"\">mirror</a></span></div></div>";
		if (rel.body)
			html += "<h3>Notes</h3>" + renderText(rel.body, "Markdown", tag + ".md");
		html += assetsTable(rel.assets);
		html += sourceArchivesHtml(info.repo, tag);
		main.innerHTML = html;
		document.title = title + " - " + info.repo + " - Splux Git";
		localizeTimes(main);
	}

	function paintReleases(info, releases, latestTag) {
		if (!main)
			return;
		var html = navHtml(info.repo, "releases");
		html += "<h2>Releases</h2><hr class=\"rule\">";
		html += "<p>GitHub releases for this tree. ISO files and other assets stay on GitHub. Notes are Markdown. <a href=\"" +
			esc(repoHref(info.repo) + "releases/latest/") + "\">Latest</a></p>";
		html += "<p><label for=\"git-filter\">Filter</label> <input id=\"git-filter\" type=\"search\" placeholder=\"release\"></p>";
		if (!releases || !releases.length)
			html += "<p class=\"muted\">No GitHub releases yet.</p>";
		else {
			html += "<div class=\"release-list\" id=\"git-releases\">";
			for (var i = 0; i < releases.length; i++)
				html += releaseArticle(releases[i], info.repo, latestTag);
			html += "</div>";
		}
		main.innerHTML = html;
		document.title = "Releases - " + info.repo + " - Splux Git";
		bindFilter();
		localizeTimes(main);
	}

	function knownRepo(name) {
		for (var i = 0; i < REPOS.length; i++) {
			if (REPOS[i] === name)
				return true;
		}
		return false;
	}

	function refreshRepo(info) {
		var repo = info.repo;
		if (!knownRepo(repo))
			return;
		return colorsReady().then(function () {
			return Promise.all([
				fetchLangs(repo).catch(function () { return null; }),
				fetchCommits(repo, info.kind === "log" ? 100 : 20).catch(function () { return null; }),
				fetchRepo(repo).catch(function () { return null; }),
				fetchTags(repo).catch(function () { return null; }),
				fetchReleases(repo).catch(function () { return null; }),
				fetchLatestRelease(repo).catch(function () { return null; })
			]);
		}).then(function (rows) {
			var langs = rows[0];
			var commits = rows[1];
			var meta = rows[2];
			var tags = rows[3];
			var releases = rows[4];
			var latest = rows[5];
			var changed = 0;
			if (langs && langs.length) {
				var box = document.getElementById("git-langs");
				if (box) {
					paintLangs(box, langs, repo);
					changed++;
				}
			}
			if (commits && commits.length) {
				var wrap = document.getElementById("git-recent") ||
					document.getElementById("git-log");
				var table = wrap ? wrap.querySelector("table.git-log") : null;
				if (table && mergeCommitRows(table, commits, repo, false))
					changed++;
				if (meta && document.getElementById("git-head")) {
					var sha = commits[0].sha;
					document.getElementById("git-head").innerHTML =
						"<a href=\"" + esc(commitHref(repo, sha)) + "\"><code>" +
						esc(commits[0].short) + "</code></a>";
				}
			}
			if (meta && document.getElementById("git-ncommits") &&
				typeof meta.size === "number") {
				/* keep baked commit count unless GitHub reports more via commits list */
			}
			if (tags && document.getElementById("git-ntags")) {
				var ntagsEl = document.getElementById("git-ntags");
				var ntags = String(tags.length);
				if (ntagsEl.textContent.replace(/\s/g, "") !== ntags) {
					ntagsEl.innerHTML = "<a href=\"" +
						esc(repoHref(repo) + "tags/") + "\">" +
						esc(ntags) + "</a>";
					changed++;
				}
			}
			if (releases && document.getElementById("git-nreleases")) {
				var nrelEl = document.getElementById("git-nreleases");
				var nrel = String(releases.length);
				if (nrelEl.textContent.replace(/\s/g, "") !== nrel) {
					nrelEl.innerHTML = "<a href=\"" +
						esc(repoHref(repo) + "releases/") + "\">" +
						esc(nrel) + "</a>";
					changed++;
				}
			}
			if (latest && latest.tag_name && document.getElementById("git-latest")) {
				var latestEl = document.getElementById("git-latest");
				if (latestEl.textContent.replace(/\s/g, "") !== latest.tag_name) {
					latestEl.innerHTML = "<a href=\"" +
						esc(repoHref(repo) + "releases/latest/") +
						"\"><code>" + esc(latest.tag_name) + "</code></a>";
					changed++;
				}
			}
			if (changed)
				showLive();
		});
	}

	function refreshTags(info) {
		if (!knownRepo(info.repo))
			return;
		return Promise.all([
			fetchTags(info.repo),
			fetchReleases(info.repo).catch(function () { return []; })
		]).then(function (rows) {
			var tags = rows[0] || [];
			var releases = rows[1] || [];
			var relset = {};
			for (var i = 0; i < releases.length; i++) {
				if (releases[i] && releases[i].tag_name)
					relset[releases[i].tag_name] = true;
			}
			var table = document.getElementById("git-tag-table");
			if (table && mergeTagRows(table, tags, info.repo, relset))
				showLive();
		});
	}

	function refreshReleases(info) {
		if (!knownRepo(info.repo))
			return;
		return Promise.all([
			fetchReleases(info.repo),
			fetchLatestRelease(info.repo).catch(function () { return null; })
		]).then(function (rows) {
			var releases = rows[0] || [];
			var latest = rows[1];
			var latestTag = (latest && latest.tag_name) ||
				(releases[0] && releases[0].tag_name) || "";
			var list = document.getElementById("git-releases");
			if (list && mergeReleaseList(list, releases, info.repo, latestTag))
				showLive();
		});
	}

	function refreshIndex() {
		return Promise.all(REPOS.map(function (repo) {
			return fetchRepo(repo).then(function (meta) {
				return fetchCommits(repo, 1).then(function (c) {
					return { repo: repo, meta: meta, commits: c };
				});
			}).catch(function () { return null; });
		})).then(function (rows) {
			var table = document.getElementById("git-repos");
			if (!table)
				return;
			var changed = 0;
			for (var i = 0; i < rows.length; i++) {
				if (!rows[i] || !rows[i].commits || !rows[i].commits.length)
					continue;
				var tr = table.querySelector("tr[data-repo=\"" + rows[i].repo + "\"]");
				if (!tr)
					continue;
				var sha = rows[i].commits[0].sha;
				var short = rows[i].commits[0].short;
				var cells = tr.querySelectorAll("td");
				if (cells[2]) {
					var cur = cells[2].textContent.replace(/\s/g, "");
					if (cur !== short) {
						cells[2].innerHTML = "<a href=\"" +
							esc(commitHref(rows[i].repo, sha)) + "\"><code>" +
							esc(short) + "</code></a>";
						changed++;
					}
				}
				if (cells[4] && rows[i].commits[0].iso)
					cells[4].textContent = dayOf(rows[i].commits[0].iso);
			}
			if (changed)
				showLive();
		});
	}

	function refreshUser(info) {
		if (!info.user || !validLogin(info.user))
			return;
		return fetchUser(info.user).then(function (u) {
			var nameEl = document.querySelector(".profile-name");
			var bio = document.querySelector(".profile-body p:not(.profile-name)");
			if (u.name && nameEl)
				nameEl.textContent = u.name;
			if (u.bio && bio)
				bio.textContent = u.bio;
			showLive();
		}).catch(function () {});
	}

	function hydrate(info) {
		if (!info.hydrate || !main)
			return Promise.resolve();
		if (info.kind === "commit" && knownRepo(info.repo) && info.sha) {
			return json(API + "/repos/" + OWNER + "/" + info.repo +
				"/commits/" + info.sha).then(function (c) {
				paintCommit(info, c);
			});
		}
		if (info.kind === "blob" && knownRepo(info.repo) && info.path) {
			return fetchContents(info.repo, info.path).then(function (item) {
				paintBlob(info, item);
			});
		}
		if (info.kind === "tree" && knownRepo(info.repo)) {
			return fetchContents(info.repo, info.path).then(function (item) {
				paintTree(info, item);
			});
		}
		if (info.kind === "people" && knownRepo(info.repo)) {
			return fetchContributors(info.repo).then(function (list) {
				var items = [];
				for (var i = 0; list && i < list.length; i++) {
					if (!list[i] || list[i].type === "Anonymous")
						continue;
					items.push({
						login: list[i].login || "",
						name: list[i].login || "",
						avatar: list[i].avatar_url || "",
						count: list[i].contributions || "",
						repo: info.repo
					});
				}
				var html = navHtml(info.repo, "people");
				html += "<h2>People</h2><hr class=\"rule\">";
				html += "<p>Everyone who authored a commit in " + esc(info.repo) +
					". <a href=\"" + esc(gitHost + "/users/") +
					"\">All people</a></p>";
				html += "<table class=\"pkgs git-people\" id=\"git-people-table\"><thead><tr><th>Person</th><th>Commits</th><th>Last commit</th><th>When</th></tr></thead><tbody>";
				for (var j = 0; j < items.length; j++)
					html += peopleRow(items[j]);
				html += "</tbody></table>";
				main.innerHTML = html;
				document.title = "People - " + info.repo + " - Splux Git";
				bindFilter();
			});
		}
		if (info.kind === "tags" && knownRepo(info.repo)) {
			return Promise.all([
				fetchTags(info.repo),
				fetchReleases(info.repo).catch(function () { return []; })
			]).then(function (rows) {
				paintTags(info, rows[0], rows[1]);
			});
		}
		if (info.kind === "tag" && knownRepo(info.repo) && info.path) {
			return Promise.all([
				fetchTags(info.repo),
				fetchReleases(info.repo).catch(function () { return []; })
			]).then(function (rows) {
				var tags = rows[0] || [];
				var found = null;
				for (var i = 0; i < tags.length; i++) {
					if (tags[i] && tags[i].name === info.path) {
						found = tags[i];
						break;
					}
				}
				paintTag(info, found || { name: info.path }, rows[1]);
			});
		}
		if (info.kind === "releases" && knownRepo(info.repo)) {
			return Promise.all([
				fetchReleases(info.repo),
				fetchLatestRelease(info.repo).catch(function () { return null; })
			]).then(function (rows) {
				var latest = rows[1];
				paintReleases(info, rows[0], latest && latest.tag_name);
			});
		}
		if ((info.kind === "release" || info.kind === "latest") &&
			knownRepo(info.repo)) {
			var work = info.kind === "latest"
				? fetchLatestRelease(info.repo)
				: fetchReleaseByTag(info.repo, info.path);
			return Promise.all([
				work,
				fetchLatestRelease(info.repo).catch(function () { return null; })
			]).then(function (rows) {
				var latest = rows[1];
				paintRelease(info, rows[0], latest && latest.tag_name,
					info.kind === "latest" ? "latest" : "release");
			});
		}
		if (info.kind === "user" && validLogin(info.user)) {
			return fetchUser(info.user).then(function (u) {
				return Promise.all(REPOS.map(function (repo) {
					return cached("git-author-" + repo + "-" + info.user,
						API + "/repos/" + OWNER + "/" + repo +
						"/commits?author=" + encodeURIComponent(info.user) +
						"&per_page=20").catch(function () { return []; });
				})).then(function (lists) {
					var items = [];
					for (var i = 0; i < lists.length; i++) {
						for (var j = 0; j < lists[i].length; j++)
							items.push(fromCommit(lists[i][j], REPOS[i]));
					}
					items.sort(function (a, b) {
						if (a.iso < b.iso) return 1;
						if (a.iso > b.iso) return -1;
						return 0;
					});
					var table = "";
					if (items.length) {
						table = "<table class=\"pkgs git-log\"><thead><tr><th>Commit</th><th>Repository</th><th>Subject</th><th>Author</th><th>When</th></tr></thead><tbody>";
						for (var k = 0; k < items.length; k++)
							table += commitRow(items[k], { showRepo: true });
						table += "</tbody></table>";
					}
					paintUser(u, table);
					localizeTimes(main);
				});
			});
		}
		return Promise.resolve();
	}

	function ready() {
		bindFilter();
		localizeTimes(document);
		if (window.SpluxRender && main)
			SpluxRender.apply(main);
		var info = pageInfo();
		var work = colorsReady();
		if (info.hydrate) {
			work = work.then(function () { return hydrate(info); })
				.catch(function () {});
			return work;
		}
		if (info.kind === "index" || info.kind === "users")
			work = work.then(refreshIndex).catch(function () {});
		if (info.kind === "repo" || info.kind === "log")
			work = work.then(function () { return refreshRepo(info); })
				.catch(function () {});
		if (info.kind === "people" || info.kind === "repo")
			work = work.then(function () { return refreshPeople(info); })
				.catch(function () {});
		if (info.kind === "tags" || info.kind === "tag" || info.kind === "refs")
			work = work.then(function () { return refreshTags(info); })
				.catch(function () {});
		if (info.kind === "releases" || info.kind === "release" ||
			info.kind === "latest")
			work = work.then(function () { return refreshReleases(info); })
				.catch(function () {});
		if (info.kind === "user")
			work = work.then(function () { return refreshUser(info); })
				.catch(function () {});
		return work;
	}

	if (document.readyState === "loading")
		document.addEventListener("DOMContentLoaded", ready);
	else
		ready();
})();
