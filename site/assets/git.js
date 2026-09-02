// Fill /git/ with GitHub metadata and whether Splux Git answers.
(function () {
	var API = "https://api.github.com/repos/RobertFlexx/";
	var ACCEPT = { Accept: "application/vnd.github+json" };
	var thisScript = document.currentScript ||
		document.querySelector("script[src*=\"git.js\"]");
	var gitHost = (thisScript && thisScript.getAttribute("data-git")) ||
		"https://git.splux.robertflexx.dev";
	gitHost = String(gitHost).replace(/\/+$/, "");

	function esc(s) {
		return String(s)
			.replace(/&/g, "&amp;")
			.replace(/</g, "&lt;")
			.replace(/>/g, "&gt;")
			.replace(/"/g, "&quot;");
	}

	function json(url) {
		return fetch(url, { headers: ACCEPT }).then(function (r) {
			if (!r.ok)
				throw new Error(String(r.status));
			return r.json();
		});
	}

	function when(iso) {
		if (!iso)
			return "";
		var d = new Date(iso);
		if (isNaN(d.getTime()))
			return iso;
		try {
			return d.toLocaleString(undefined, {
				year: "numeric",
				month: "short",
				day: "numeric"
			});
		} catch (e) {
			return iso.slice(0, 10);
		}
	}

	var status = document.getElementById("git-status");
	if (status) {
		fetch(gitHost + "/api/v1/version", { mode: "cors" }).then(function (r) {
			if (!r.ok)
				throw new Error(String(r.status));
			return r.json();
		}).then(function (v) {
			var ver = (v && (v.version || v.forgejo)) || "up";
			status.innerHTML = "reachable (" + esc(String(ver)) + ")";
		}).catch(function () {
			status.textContent =
				"not reachable from this browser yet; clone GitHub until DNS and TLS exist";
			var rows = document.querySelectorAll("#git-repos tr[data-repo]");
			for (var j = 0; j < rows.length; j++) {
				var name = rows[j].getAttribute("data-repo");
				var a = rows[j].querySelector("a.name");
				if (a && name)
					a.setAttribute("href",
						"https://github.com/RobertFlexx/" + name);
			}
		});
	}

	var rows = document.querySelectorAll("#git-repos tr[data-repo]");
	for (var i = 0; i < rows.length; i++) {
		(function (row) {
			var name = row.getAttribute("data-repo");
			json(API + encodeURIComponent(name)).then(function (repo) {
				var lang = row.querySelector(".lang");
				var pushed = row.querySelector(".pushed");
				if (lang && repo.language)
					lang.textContent = repo.language;
				if (pushed && repo.pushed_at)
					pushed.textContent = when(repo.pushed_at);
			}).catch(function () {});
		})(rows[i]);
	}
})();
