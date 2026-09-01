// Package data is generated from the official repositories.
(function () {
	var form = document.getElementById("pkg-search");
	var input = document.getElementById("q");
	var table = document.getElementById("pkg-table");
	var stats = document.getElementById("pkg-stats");
	if (!form || !input || !table) return;

	var rows = table.querySelectorAll("tbody tr");
	var total = rows.length;

	function currentRepo() {
		var params = new URLSearchParams(window.location.search);
		return params.get("repo") || "all";
	}

	function apply() {
		var q = input.value.toLowerCase();
		var repo = currentRepo();
		var shown = 0;
		for (var i = 0; i < rows.length; i++) {
			var row = rows[i];
			var text = row.getAttribute("data-search") || "";
			var rowRepo = row.getAttribute("data-repo") || "";
			var ok = text.indexOf(q) !== -1 &&
				(repo === "all" || rowRepo === repo);
			row.hidden = !ok;
			if (ok) shown++;
		}
		if (stats) {
			stats.textContent = shown + " of " + total + " packages";
		}
	}

	var params = new URLSearchParams(window.location.search);
	if (params.get("q")) input.value = params.get("q");

	input.addEventListener("input", apply);
	form.addEventListener("submit", function (e) {
		e.preventDefault();
		apply();
		var next = new URL(window.location.href);
		if (input.value) next.searchParams.set("q", input.value);
		else next.searchParams.delete("q");
		history.replaceState(null, "", next);
	});
	apply();
})();
