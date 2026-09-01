// Handbook tabs. No framework. Hash URLs stay shareable.
(function () {
	function ready() {
		var sets = document.querySelectorAll("[data-tabs]");
		if (!sets.length)
			return;
		document.documentElement.classList.add("js-tabs");
		for (var i = 0; i < sets.length; i++)
			initSet(sets[i]);
		applyHash();
		window.addEventListener("hashchange", applyHash);
	}

	function tabsOf(set) {
		var n = set.firstElementChild;
		var list = null;
		while (n) {
			if (n.getAttribute && n.classList.contains("tablist")) {
				list = n;
				break;
			}
			n = n.nextElementSibling;
		}
		if (!list)
			return [];
		return list.querySelectorAll('[role="tab"]');
	}

	function initSet(set) {
		var tabs = tabsOf(set);
		var selected = null;
		for (var i = 0; i < tabs.length; i++) {
			bindTab(set, tabs, tabs[i], i);
			if (!selected && tabs[i].getAttribute("aria-selected") === "true")
				selected = tabs[i];
		}
		if (!selected && tabs.length)
			selected = tabs[0];
		if (selected)
			selectTab(set, selected, false);
	}

	function bindTab(set, tabs, tab, index) {
		tab.addEventListener("click", function () {
			selectTab(set, tab, true);
		});
		tab.addEventListener("keydown", function (e) {
			var next = -1;
			if (e.key === "ArrowRight" || e.key === "ArrowDown")
				next = (index + 1) % tabs.length;
			else if (e.key === "ArrowLeft" || e.key === "ArrowUp")
				next = (index - 1 + tabs.length) % tabs.length;
			else if (e.key === "Home")
				next = 0;
			else if (e.key === "End")
				next = tabs.length - 1;
			else
				return;
			e.preventDefault();
			tabs[next].focus();
			selectTab(set, tabs[next], true);
		});
	}

	function selectTab(set, tab, updateHash) {
		var tabs = tabsOf(set);
		for (var i = 0; i < tabs.length; i++) {
			var on = tabs[i] === tab;
			tabs[i].setAttribute("aria-selected", on ? "true" : "false");
			tabs[i].tabIndex = on ? 0 : -1;
			var id = tabs[i].getAttribute("aria-controls");
			var panel = id ? document.getElementById(id) : null;
			if (!panel)
				continue;
			if (on)
				panel.removeAttribute("hidden");
			else
				panel.setAttribute("hidden", "");
		}
		if (updateHash) {
			var hash = tab.getAttribute("data-hash");
			if (hash && history.replaceState)
				history.replaceState(null, "", "#" + hash);
			else if (hash)
				location.hash = hash;
		}
	}

	function reveal(tab) {
		var t = tab;
		while (t) {
			var set = t.closest("[data-tabs]");
			if (!set)
				break;
			selectTab(set, t, false);
			var panel = set.closest(".tabpanel");
			if (!panel)
				break;
			t = document.querySelector(
				'[role="tab"][aria-controls="' + panel.id + '"]'
			);
		}
	}

	function applyHash() {
		var hash = (location.hash || "").replace(/^#/, "");
		if (!hash)
			return;
		var tab = document.querySelector(
			'[role="tab"][data-hash="' + hash + '"]'
		);
		if (!tab) {
			var el = document.getElementById(hash);
			if (el) {
				var panel = el.closest(".tabpanel") ||
					(el.classList.contains("tabpanel") ? el : null);
				if (panel)
					tab = document.querySelector(
						'[role="tab"][aria-controls="' + panel.id + '"]'
					);
			}
		}
		if (tab)
			reveal(tab);
	}

	if (document.readyState === "loading")
		document.addEventListener("DOMContentLoaded", ready);
	else
		ready();
})();
