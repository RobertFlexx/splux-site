// Refresh ISO tags and news from GitHub so a delayed Pages build
// cannot hide a new release or commit. Baked HTML stays if this fails.
(function () {
	var API = "https://api.github.com/repos/RobertFlexx/";
	var ACCEPT = { Accept: "application/vnd.github+json" };
	var REPOS = [
		{ path: "SPS", label: "SPS" },
		{ path: "sps-core", label: "sps-core" },
		{ path: "sps-extra", label: "sps-extra" },
		{ path: "splux-site", label: "splux-site" }
	];

	var feed = document.getElementById("live-feed");
	var brief = document.getElementById("live-brief");
	var isoEl = document.getElementById("live-iso");
	var tagEl = document.getElementById("live-tag");
	var dateEl = document.getElementById("live-date");
	if (!feed && !brief && !isoEl && !tagEl)
		return;

	function esc(s) {
		return String(s)
			.replace(/&/g, "&amp;")
			.replace(/</g, "&lt;")
			.replace(/>/g, "&gt;")
			.replace(/"/g, "&quot;");
	}

	function dayOf(iso) {
		var d = String(iso || "");
		var t = d.indexOf("T");
		return t === -1 ? d : d.slice(0, t);
	}

	function json(url) {
		return fetch(url, { headers: ACCEPT, cache: "no-store" }).then(function (r) {
			if (!r.ok)
				throw new Error(String(r.status));
			return r.json();
		});
	}

	function firstLine(msg) {
		msg = String(msg || "");
		var n = msg.indexOf("\n");
		return n === -1 ? msg : msg.slice(0, n);
	}

	function readItems(root) {
		var items = [];
		if (!root)
			return items;
		var articles = root.querySelectorAll("article.item");
		for (var i = 0; i < articles.length; i++) {
			var a = articles[i];
			var time = a.querySelector("time");
			var kind = a.querySelector(".kind");
			var link = a.querySelector("h3 a");
			var summary = a.querySelector(".summary");
			var meta = a.querySelector(".meta");
			if (!time || !link)
				continue;
			var repo = "";
			if (meta) {
				repo = meta.textContent.replace(time.textContent, "");
				if (kind)
					repo = repo.replace(kind.textContent, "");
				repo = repo.replace(/\s+/g, " ").trim();
			}
			items.push({
				iso: time.getAttribute("datetime") || "",
				kind: kind ? kind.textContent : "commit",
				repo: repo,
				url: link.getAttribute("href") || "",
				title: link.textContent || "",
				summary: summary ? summary.textContent : ""
			});
		}
		return items;
	}

	function renderItem(it, hideSummary) {
		var html = "<article class=\"item\">";
		html += "<p class=\"meta\"><time datetime=\"" + esc(it.iso) + "\">" +
			esc(dayOf(it.iso)) + "</time> <span class=\"kind\">" +
			esc(it.kind) + "</span> " + esc(it.repo) + "</p>";
		html += "<h3><a href=\"" + esc(it.url) + "\">" + esc(it.title) + "</a></h3>";
		if (!hideSummary && it.summary)
			html += "<p class=\"summary\">" + esc(it.summary) + "</p>";
		html += "</article>";
		return html;
	}

	function merge(base, extra) {
		var seen = {};
		var out = [];
		function add(it) {
			if (!it || !it.url || seen[it.url])
				return;
			seen[it.url] = true;
			out.push(it);
		}
		var i;
		for (i = 0; i < extra.length; i++)
			add(extra[i]);
		for (i = 0; i < base.length; i++)
			add(base[i]);
		out.sort(function (a, b) {
			if (a.iso < b.iso)
				return 1;
			if (a.iso > b.iso)
				return -1;
			return 0;
		});
		return out;
	}

	function paint(root, items, limit, hideSummary) {
		if (!root)
			return;
		var n = items.length;
		if (limit && n > limit)
			n = limit;
		var html = "<div class=\"feed\">";
		for (var i = 0; i < n; i++)
			html += renderItem(items[i], hideSummary);
		html += "</div>";
		root.innerHTML = html;
	}

	function shortSha(sha) {
		sha = String(sha || "");
		return sha.length > 7 ? sha.slice(0, 7) : sha;
	}

	function setSha(id, repoPath, sha) {
		var el = document.getElementById(id);
		if (!el || !sha)
			return;
		el.innerHTML = "<a href=\"https://github.com/RobertFlexx/" +
			esc(repoPath) + "/commit/" + esc(sha) + "\">" +
			esc(shortSha(sha)) + "</a>";
	}

	function setIso(rel) {
		if (!rel)
			return;
		var tag = rel.tag_name || rel.name || "";
		var when = dayOf(rel.published_at || "");
		if (isoEl && tag) {
			isoEl.innerHTML = "<a href=\"https://github.com/RobertFlexx/SPS/releases/latest\">" +
				esc(tag) + "</a> (" + esc(when) + ")";
		}
		if (tagEl && tag)
			tagEl.textContent = tag;
		if (dateEl && when)
			dateEl.textContent = when;
	}

	function fromReleases(list) {
		var items = [];
		for (var i = 0; i < list.length; i++) {
			var r = list[i];
			if (!r || r.draft)
				continue;
			var body = r.body ? String(r.body).replace(/\s+/g, " ").slice(0, 900) : "";
			items.push({
				iso: r.published_at || "",
				kind: "release",
				repo: "SPS",
				url: r.html_url || "",
				title: r.name || r.tag_name || "",
				summary: body
			});
		}
		return items;
	}

	function fromCommits(list, label) {
		var items = [];
		for (var i = 0; i < list.length; i++) {
			var c = list[i];
			if (!c)
				continue;
			var commit = c.commit || {};
			var when = (commit.committer && commit.committer.date) ||
				(commit.author && commit.author.date) || "";
			items.push({
				iso: when,
				kind: "commit",
				repo: label,
				url: c.html_url || "",
				title: firstLine(commit.message),
				summary: ""
			});
		}
		return items;
	}

	var req = [json(API + "SPS/releases?per_page=100")];
	for (var r = 0; r < REPOS.length; r++)
		req.push(json(API + REPOS[r].path + "/commits?per_page=100"));

	Promise.all(req).then(function (rows) {
		var releases = rows[0] || [];
		var extra = fromReleases(releases);
		for (var i = 0; i < REPOS.length; i++)
			extra = extra.concat(fromCommits(rows[i + 1] || [], REPOS[i].label));

		var baked = readItems(feed).concat(readItems(brief));
		var items = merge(baked, extra);
		paint(feed, items, 0, false);
		paint(brief, items, 8, true);

		var latest = null;
		for (var j = 0; j < releases.length; j++) {
			if (releases[j] && !releases[j].draft) {
				latest = releases[j];
				break;
			}
		}
		setIso(latest);

		for (var k = 0; k < REPOS.length; k++) {
			var commits = rows[k + 1] || [];
			var sha = commits[0] && commits[0].sha;
			if (REPOS[k].path === "SPS")
				setSha("live-sps", "SPS", sha);
			else if (REPOS[k].path === "sps-core")
				setSha("live-core", "sps-core", sha);
			else if (REPOS[k].path === "sps-extra")
				setSha("live-extra", "sps-extra", sha);
		}
	}).catch(function () {
		/* keep the HTML from the last site build */
	});
})();
