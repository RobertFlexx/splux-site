// Filter the static git index. Pages are built with the handbook;
// GitHub is only a clone mirror, not a runtime backend.
(function () {
	function ready() {
		var input = document.getElementById("git-filter");
		var table = document.getElementById("git-repos");
		if (input && table)
			bindFilter(input, table);
		var tree = document.querySelector("table.git-tree");
		if (input && tree)
			bindFilter(input, tree);
	}

	function bindFilter(input, table) {
		function apply() {
			var q = (input.value || "").toLowerCase();
			var rows = table.querySelectorAll("tbody tr");
			for (var i = 0; i < rows.length; i++) {
				var hay = rows[i].getAttribute("data-search") ||
					rows[i].textContent || "";
				rows[i].hidden = q !== "" &&
					hay.toLowerCase().indexOf(q) === -1;
			}
		}
		input.addEventListener("input", apply);
	}

	if (document.readyState === "loading")
		document.addEventListener("DOMContentLoaded", ready);
	else
		ready();
})();
