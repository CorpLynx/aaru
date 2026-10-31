// Resolves the Aaru component namespace: compiled bundle first, source fallback (for local preview before compile).
(function () {
  var FILES = ["core/Button","core/IconButton","core/Badge","core/Card","core/Kbd","core/Logo","forms/Input","forms/Select","forms/Checkbox","forms/Switch","forms/SegmentedControl","navigation/Tabs","navigation/HistoryItem","feedback/Tooltip","feedback/Dialog","feedback/Toast","security/SealBadge","security/SealPopover","security/VaultFileRow","metrics/GeneratingPulse","metrics/MetricChip","metrics/ContextBar","metrics/AmbientStatus","chat/MessageBubble","chat/Citation","chat/Composer","chat/ModelToggle"];
  function find() {
    var keys = Object.keys(window);
    for (var i = 0; i < keys.length; i++) {
      try { var v = window[keys[i]]; if (v && typeof v === "object" && v.SealBadge && v.Composer) return v; } catch (e) {}
    }
    return null;
  }
  function loadScript(src) {
    return new Promise(function (res, rej) { var s = document.createElement("script"); s.src = src; s.onload = res; s.onerror = rej; document.head.appendChild(s); });
  }
  window.loadAaruDS = async function (root) {
    root = root || "./";
    var ns = find(); if (ns) return ns;
    try { await loadScript(root + "_ds_bundle.js"); ns = find(); if (ns) return ns; } catch (e) {}
    var NS = {};
    var srcs = await Promise.all(FILES.map(function (f) { return fetch(root + "components/" + f + ".jsx").then(function (r) { return r.text(); }); }));
    for (var i = 0; i < FILES.length; i++) {
      var src = srcs[i];
      var names = []; src.replace(/export (?:function|const) (\w+)/g, function (_, n) { names.push(n); });
      src = src.replace(/^import .*$/mg, "").replace(/export (function|const)/g, "$1");
      var code = Babel.transform(src, { presets: ["react"] }).code;
      var deps = Object.keys(NS);
      var fn = new Function(["React"].concat(deps).join(","), code + "\nreturn {" + names.join(",") + "};");
      Object.assign(NS, fn.apply(null, [React].concat(deps.map(function (d) { return NS[d]; }))));
    }
    window.AaruDSLocal = NS;
    return NS;
  };
})();
