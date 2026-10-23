// Resolve the monitor that just received focus into what the card shows.
// Kept free of QML so the numbering rules can be tested with plain Node.

function info(monitors, name) {
  // Hyprland.monitors.values is a QML list in the shell, not necessarily a JS
  // Array, so accept anything array-like instead of trusting Array.isArray.
  var list = monitors && typeof monitors.length === "number" ? monitors : []
  var wanted = String(name === undefined || name === null ? "" : name)
  var found = -1
  for (var i = 0; i < list.length; i++) {
    if (String(list[i] && list[i].name || "") === wanted) {
      found = i
      break
    }
  }
  if (found < 0) {
    return { found: false, number: 0, count: list.length, name: wanted, description: "" }
  }
  var monitor = list[found]
  return {
    found: true,
    number: found + 1,
    count: list.length,
    name: String(monitor.name || ""),
    description: String(monitor.description || "").trim()
  }
}

function contains(rect, x, y, pad) {
  if (!rect) return false
  var p = Number(pad) || 0
  return x >= rect.x - p && x <= rect.x + rect.width + p
    && y >= rect.y - p && y <= rect.y + rect.height + p
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { info: info, contains: contains }
}
