// Refresh ISO tags and news from GitHub so a delayed Pages build
// cannot hide a new release or commit. Baked HTML stays if this fails.
// News times are rewritten to the viewer's local timezone.
(function () {
	var API = "https://api.github.com/repos/RobertFlexx/";
	var ACCEPT = { Accept: "application/vnd.github+json" };
	var PER = 20;
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
	var thisScript = document.currentScript ||
		document.querySelector("script[src*=\"live.js\"]");
	var dataRoot = (thisScript && thisScript.getAttribute("data-root")) || "./";
	var gitHost = (thisScript && thisScript.getAttribute("data-git")) ||
		"https://splux.robertflexx.dev/git";
	gitHost = String(gitHost).replace(/\/+$/, "");
	if (!feed && !brief && !isoEl && !tagEl)
		return;

	function esc(s) {
		return String(s)
			.replace(/&/g, "&amp;")
			.replace(/</g, "&lt;")
			.replace(/>/g, "&gt;")
			.replace(/"/g, "&quot;");
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

	function newsNest() {
		var p = location.pathname.replace(/\/index\.html$/, "").replace(/\/+$/, "");
		return /\/news\/\d+$/.test(p);
	}

	function newsPage() {
		var p = location.pathname.replace(/\/index\.html$/, "").replace(/\/+$/, "");
		var m = p.match(/\/news\/(\d+)$/);
		if (m)
			return parseInt(m[1], 10) || 1;
		return 1;
	}

	function newsHref(n, nest) {
		if (n < 1)
			n = 1;
		if (nest) {
			if (n <= 1)
				return "../";
			return "../" + n + "/";
		}
		if (n <= 1)
			return "./";
		return n + "/";
	}

	function readItems(root) {
		var items = [];
		if (!root)
			return items;
		var articles = root.querySelectorAll("article.item");
		for (var i = 0; i < articles.length; i++) {
			var a = articles[i];
			var time = a.querySelector("time");
			var kindEl = a.querySelector(".kind");
			var link = a.querySelector("h3 a");
			var summary = a.querySelector(".summary");
			if (!time || !link)
				continue;
			items.push({
				iso: time.getAttribute("datetime") || "",
				kind: a.getAttribute("data-kind") || (kindEl ? kindEl.textContent : "commit"),
				repo: a.getAttribute("data-repo") || "",
				author: a.getAttribute("data-author") || "",
				verified: a.getAttribute("data-verified") === "yes",
				avatar: a.getAttribute("data-avatar") || "",
				url: forgeCommitHref(link.getAttribute("href") || ""),
				title: link.textContent || "",
				summary: summary ? summary.textContent : ""
			});
		}
		return items;
	}

	function fromJson(list) {
		var items = [];
		if (!list || !list.length)
			return items;
		for (var i = 0; i < list.length; i++) {
			var it = list[i];
			if (!it || !it.url)
				continue;
			items.push({
				iso: it.iso || "",
				kind: it.kind || "commit",
				repo: it.repo || "",
				author: it.author || "",
				verified: !!it.verified,
				avatar: it.avatar || "",
				url: forgeCommitHref(it.url),
				title: it.title || "",
				summary: it.summary || ""
			});
		}
		return items;
	}

	function avatarOf(it) {
		var av = it && it.avatar ? String(it.avatar) : "";
		if (/^https:\/\/(avatars\.githubusercontent\.com\/|github\.com\/)/.test(av))
			return av;
		var name = it && it.author ? String(it.author) : "";
		if (/^[A-Za-z0-9-]+$/.test(name))
			return "https://github.com/" + name + ".png?size=48";
		return "";
	}

	function profileOf(it) {
		var name = it && it.author ? String(it.author) : "";
		if (/^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$/.test(name) && name.length <= 39)
			return gitHost + "/users/" + name + "/";
		return "";
	}

	function renderItem(it, hideSummary) {
		var av = avatarOf(it);
		var profile = profileOf(it);
		var html = "<article class=\"item\" data-kind=\"" + esc(it.kind || "") +
			"\" data-repo=\"" + esc(it.repo || "") +
			"\" data-author=\"" + esc(it.author || "") +
			"\" data-verified=\"" + (it.verified ? "yes" : "no") +
			"\" data-avatar=\"" + esc(av) + "\">";
		html += "<p class=\"meta\"><time datetime=\"" + esc(it.iso) + "\">" +
			esc(formatLocal(it.iso)) + "</time> <span class=\"kind\">" +
			esc(it.kind) + "</span> " + esc(it.repo);
		if (it.author || av) {
			if (profile)
				html += " <a class=\"who\" href=\"" + esc(profile) + "\">";
			else
				html += " <span class=\"who\">";
			if (av)
				html += "<img class=\"avatar\" src=\"" + esc(av) +
					"\" width=\"24\" height=\"24\" alt=\"\" loading=\"lazy\">";
			if (it.author)
				html += esc(it.author);
			html += profile ? "</a>" : "</span>";
		}
		if (it.verified)
			html += " <span class=\"verified\">verified</span>";
		html += "</p>";
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

	function paintPage(root, items, page, per) {
		if (!root)
			return;
		var pages = Math.max(1, Math.ceil(items.length / per) || 1);
		if (page > pages)
			page = pages;
		if (page < 1)
			page = 1;
		var start = (page - 1) * per;
		var slice = items.slice(start, start + per);
		paint(root, slice, 0, false);
		return pages;
	}

	function inWindow(i, page, pages) {
		var lo = page - 2;
		var hi = page + 2;
		if (lo < 1) {
			hi += (1 - lo);
			lo = 1;
		}
		if (hi > pages) {
			lo -= (hi - pages);
			hi = pages;
		}
		if (lo < 1)
			lo = 1;
		return i === 1 || i === pages || (i >= lo && i <= hi);
	}

	function paintPager(page, pages, nest, per) {
		var nav = document.getElementById("news-pager");
		if (!nav)
			return;
		nav.setAttribute("data-page", String(page));
		nav.setAttribute("data-pages", String(pages));
		nav.setAttribute("data-per", String(per));
		if (pages <= 1) {
			nav.hidden = true;
			nav.innerHTML = "";
			return;
		}
		nav.hidden = false;
		var html = "<p class=\"pager-status\">Page " + page + " of " + pages + "</p>";
		html += "<p class=\"pager-links\">";
		if (page > 1)
			html += "<a rel=\"prev\" href=\"" + esc(newsHref(page - 1, nest)) + "\">prev</a> ";
		var needDots = false;
		for (var i = 1; i <= pages; i++) {
			if (!inWindow(i, page, pages)) {
				needDots = true;
				continue;
			}
			if (needDots) {
				html += "<span class=\"pager-gap\">...</span> ";
				needDots = false;
			}
			if (i === page)
				html += "<a href=\"" + esc(newsHref(i, nest)) +
					"\" aria-current=\"page\">" + i + "</a> ";
			else
				html += "<a href=\"" + esc(newsHref(i, nest)) + "\">" + i + "</a> ";
		}
		if (page < pages)
			html += "<a rel=\"next\" href=\"" + esc(newsHref(page + 1, nest)) + "\">next</a>";
		html += "</p>";
		html += "<form class=\"pager-jump\" id=\"news-jump\" action=\"#\">";
		html += "<label for=\"news-page-n\">Go to page</label> ";
		html += "<input id=\"news-page-n\" name=\"n\" type=\"number\" min=\"1\" max=\"" +
			pages + "\" value=\"" + page + "\" inputmode=\"numeric\"> ";
		html += "<button type=\"submit\">Go</button>";
		html += "</form>";
		nav.innerHTML = html;
	}

	function shortSha(sha) {
		sha = String(sha || "");
		return sha.length > 7 ? sha.slice(0, 7) : sha;
	}

	function commitHref(repoPath, sha, htmlUrl) {
		if (gitHost && repoPath && sha)
			return gitHost + "/" + repoPath + "/commit/" + sha + "/";
		return htmlUrl || "";
	}

	function forgeCommitHref(url) {
		var u = String(url || "");
		var m = /^https:\/\/github\.com\/RobertFlexx\/([^/]+)\/commit\/([0-9a-fA-F]+)/.exec(u);
		if (m && gitHost)
			return gitHost + "/" + m[1] + "/commit/" + m[2] + "/";
		m = /^https:\/\/git\.splux\.robertflexx\.dev\/RobertFlexx\/([^/]+)\/commit\/([0-9a-fA-F]+)/.exec(u);
		if (m && gitHost)
			return gitHost + "/" + m[1] + "/commit/" + m[2] + "/";
		return u;
	}

	function setSha(id, repoPath, sha) {
		var el = document.getElementById(id);
		if (!el || !sha)
			return;
		el.innerHTML = "<a href=\"" +
			esc(commitHref(repoPath, sha, "")) + "\">" +
			esc(shortSha(sha)) + "</a>";
	}

	// live-2026-08-31-9 sorts after live-2026-08-31-15 as a string.
	function liveRank(tag) {
		var m = /^live-(\d{4})-(\d{2})-(\d{2})(?:-(\d+))?$/.exec(String(tag || ""));
		if (!m)
			return null;
		return [
			parseInt(m[1], 10),
			parseInt(m[2], 10),
			parseInt(m[3], 10),
			parseInt(m[4] || "0", 10)
		];
	}

	function liveBetter(a, b) {
		var ra = liveRank(a);
		var rb = liveRank(b);
		if (!ra)
			return false;
		if (!rb)
			return true;
		for (var i = 0; i < 4; i++) {
			if (ra[i] > rb[i])
				return true;
			if (ra[i] < rb[i])
				return false;
		}
		return false;
	}

	function pickLiveRelease(list) {
		var best = null;
		if (!list || !list.length)
			return null;
		for (var i = 0; i < list.length; i++) {
			var r = list[i];
			if (!r || r.draft)
				continue;
			var tag = r.tag_name || r.tag || "";
			if (!liveRank(tag))
				continue;
			if (!best || liveBetter(tag, best.tag_name || best.tag || ""))
				best = r;
		}
		return best;
	}

	var shownIsoTag = "";

	function rewriteDownloads(tag) {
		if (!tag)
			return;
		var encoded = encodeURIComponent(tag);
		var prefix = "https://github.com/RobertFlexx/SPS/releases/";
		var as = document.getElementsByTagName("a");
		for (var i = 0; i < as.length; i++) {
			var href = as[i].getAttribute("href") || "";
			var m = href.match(/^https:\/\/github\.com\/RobertFlexx\/SPS\/releases\/(?:latest\/download|download\/[^/]+)\/([^/?#]+)$/);
			if (m) {
				as[i].setAttribute("href", prefix + "download/" + encoded + "/" + m[1]);
				continue;
			}
			if (href === prefix + "latest" || href === prefix + "latest/" ||
			    /^https:\/\/github\.com\/RobertFlexx\/SPS\/releases\/tag\/[^/]+\/?$/.test(href))
				as[i].setAttribute("href", prefix + "tag/" + encoded);
		}
	}

	function setIso(rel) {
		if (!rel)
			return;
		var tag = rel.tag_name || rel.tag || rel.name || "";
		var when = rel.published_at || rel.published || rel.date || "";
		var href = tag
			? "https://github.com/RobertFlexx/SPS/releases/tag/" + encodeURIComponent(tag)
			: "https://github.com/RobertFlexx/SPS/releases/latest";
		if (isoEl && tag) {
			isoEl.innerHTML = "<a href=\"" + esc(href) + "\">" +
				esc(tag) + "</a> (<time datetime=\"" + esc(when) + "\">" +
				esc(formatLocal(when)) + "</time>)";
		}
		if (tagEl && tag)
			tagEl.textContent = tag;
		if (dateEl && when) {
			dateEl.setAttribute("data-iso", when);
			dateEl.setAttribute("datetime", when);
			dateEl.textContent = formatLocal(when);
		}
	}

	function applyRelease(rel) {
		if (!rel)
			return;
		var tag = rel.tag_name || rel.tag || rel.name || "";
		if (!liveRank(tag))
			return;
		if (shownIsoTag && liveBetter(shownIsoTag, tag))
			return;
		shownIsoTag = tag;
		setIso(rel);
		rewriteDownloads(tag);
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
				author: (r.author && r.author.login) || "",
				verified: false,
				avatar: (r.author && r.author.avatar_url) || "",
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
			var author = (c.author && c.author.login) ||
				(commit.author && commit.author.name) || "";
			var ver = commit.verification || {};
			items.push({
				iso: when,
				kind: "commit",
				repo: label,
				author: author,
				verified: !!ver.verified,
				avatar: (c.author && c.author.avatar_url) || "",
				url: forgeCommitHref(c.html_url || commitHref(label, c.sha, "")),
				title: firstLine(commit.message),
				summary: ""
			});
		}
		return items;
	}

	localizeTimes(document);

	document.addEventListener("submit", function (e) {
		var form = e.target;
		if (!form || form.id !== "news-jump")
			return;
		e.preventDefault();
		var input = form.querySelector("input[name=\"n\"]") ||
			document.getElementById("news-page-n");
		var nav = document.getElementById("news-pager");
		var pages = nav ? parseInt(nav.getAttribute("data-pages"), 10) || 1 : 1;
		var n = input ? parseInt(input.value, 10) : 1;
		if (isNaN(n) || n < 1)
			n = 1;
		if (n > pages)
			n = pages;
		location.href = newsHref(n, newsNest());
	});

	json(dataRoot + "data/release.json").then(function (info) {
		if (!info || !info.tag)
			return;
		applyRelease({
			tag_name: info.tag,
			published_at: info.published_at || info.date || ""
		});
	}).catch(function () {});

	function refreshCommitsAndNews(releases) {
		var needCommits = !!(feed || brief || document.getElementById("live-sps"));
		if (!needCommits)
			return;
		var extra = fromReleases(releases || []);
		var commitReqs = [];
		for (var r = 0; r < REPOS.length; r++)
			commitReqs.push(json(API + REPOS[r].path + "/commits?per_page=100")
				.catch(function () { return []; }));
		var newsReq = feed
			? json(dataRoot + "data/news.json").catch(function () { return []; })
			: Promise.resolve([]);
		Promise.all(commitReqs.concat([newsReq])).then(function (rows) {
			var i;
			for (i = 0; i < REPOS.length; i++)
				extra = extra.concat(fromCommits(rows[i] || [], REPOS[i].label));
			var baked = [];
			if (feed)
				baked = fromJson(rows[REPOS.length] || []);
			if (!baked.length)
				baked = readItems(feed).concat(readItems(brief));
			var items = merge(baked, extra);

			if (feed) {
				var nest = newsNest();
				var page = newsPage();
				var pages = Math.max(1, Math.ceil(items.length / PER) || 1);
				if (page > pages) {
					location.replace(newsHref(pages, nest));
					return;
				}
				paintPage(feed, items, page, PER);
				paintPager(page, pages, nest, PER);
			}
			paint(brief, items, 8, true);

			for (var k = 0; k < REPOS.length; k++) {
				var commits = rows[k] || [];
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
	}

	json(API + "SPS/releases?per_page=100").then(function (releases) {
		var rel = pickLiveRelease(releases);
		if (rel)
			applyRelease(rel);
		refreshCommitsAndNews(releases);
	}).catch(function () {
		refreshCommitsAndNews([]);
	});
})();
