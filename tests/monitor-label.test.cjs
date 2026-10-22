const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

// Load the QML helper as written. It is a plain script, and the workspace
// package.json above it makes Node treat a bare require() of .js as ESM.
const source = fs.readFileSync(path.join(__dirname, "..", "MonitorLabel.js"), "utf8")
const sandbox = { module: { exports: {} } }
vm.runInNewContext(source, sandbox)
const Label = sandbox.module.exports

const monitors = [
  { name: "HDMI-A-1", description: "Left panel" },
  { name: "HDMI-A-2", description: "  Right panel  " },
  { name: "DP-3", description: "" }
]

test("numbers monitors from one in compositor order", () => {
  const first = Label.info(monitors, "HDMI-A-1")
  assert.equal(first.found, true)
  assert.equal(first.number, 1)
  assert.equal(first.count, 3)
  assert.equal(first.name, "HDMI-A-1")
  assert.equal(first.description, "Left panel")
  assert.equal(Label.info(monitors, "HDMI-A-2").number, 2)
  assert.equal(Label.info(monitors, "DP-3").number, 3)
})

test("trims the description and keeps an empty one empty", () => {
  assert.equal(Label.info(monitors, "HDMI-A-2").description, "Right panel")
  assert.equal(Label.info(monitors, "DP-3").description, "")
})

test("reports an unknown monitor without inventing a number", () => {
  const unknown = Label.info(monitors, "eDP-9")
  assert.equal(unknown.found, false)
  assert.equal(unknown.number, 0)
  assert.equal(unknown.count, 3)
  assert.equal(unknown.name, "eDP-9")
  assert.equal(unknown.description, "")
})

test("tolerates missing or malformed input", () => {
  const empty = Label.info(null, "HDMI-A-1")
  assert.equal(empty.found, false)
  assert.equal(empty.number, 0)
  assert.equal(empty.count, 0)
  assert.equal(empty.name, "HDMI-A-1")
  assert.equal(Label.info([{ name: null }], "null").found, false)
  assert.equal(Label.info([{}], "").found, true)
  assert.equal(Label.info([{}], "").description, "")
})

test("accepts the QML list Hyprland.monitors.values returns", () => {
  const list = { length: 2, 0: { name: "A", description: "first" }, 1: { name: "B", description: "second" } }
  const info = Label.info(list, "B")
  assert.equal(info.found, true)
  assert.equal(info.number, 2)
  assert.equal(info.count, 2)
})

test("uses the last duplicate only by first match", () => {
  const duplicated = [{ name: "A", description: "first" }, { name: "A", description: "second" }]
  assert.equal(Label.info(duplicated, "A").number, 1)
  assert.equal(Label.info(duplicated, "A").description, "first")
})
