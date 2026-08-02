-- Tests for scripts/libs/json.lua (the rxi json lib the game uses)
local H = require("tests(vibecoded)/lua/harness")
local M = require("tests(vibecoded)/lua/mock")

M.install()
local json = dofile("scripts/libs/json.lua")

H.describe("json.lua encode/decode")

H.test("encode simple types", function()
  H.eq(json.encode(true), "true")
  H.eq(json.encode(false), "false")
  H.eq(json.encode(nil), "null")
  H.eq(json.encode(42), "42")
  H.eq(json.encode("hi"), '"hi"')
end)

H.test("decode simple types", function()
  H.eq(json.decode("true"), true)
  H.eq(json.decode("null"), nil)
  H.eq(json.decode("42"), 42)
  H.eq(json.decode('"hi"'), "hi")
end)

H.test("roundtrip nested table", function()
  local t = { a = 1, b = { c = "x", d = { 1, 2, 3 } }, e = true, f = "y" }
  local decoded = json.decode(json.encode(t))
  H.eq(decoded.a, 1)
  H.eq(decoded.b.c, "x")
  H.eq(decoded.b.d[1], 1)
  H.eq(decoded.b.d[3], 3)
  H.eq(decoded.e, true)
  H.eq(decoded.f, "y")
end)

H.test("array roundtrip", function()
  local arr = { "one", "two", 3, false }
  local decoded = json.decode(json.encode(arr))
  H.eq(#decoded, 4)
  H.eq(decoded[1], "one")
  H.eq(decoded[4], false)
end)

H.test("unicode escapes decode", function()
  H.eq(json.decode('"\\u0041\\u00e9"'), "Aé")
end)

H.test("escaped chars", function()
  H.eq(json.decode(json.encode('a"b\\c\nd')), 'a"b\\c\nd')
end)

H.test("empty table encodes to object or array", function()
  local ok = json.encode({})
  H.truthy(ok == "{}" or ok == "[]")
end)

H.test("trailing garbage errors", function()
  local ok = pcall(json.decode, "{} garbage")
  H.falsy(ok)
end)

H.test("sparse array errors", function()
  local ok = pcall(json.encode, { [1] = 1, [3] = 3 })
  H.falsy(ok)
end)

H.test("circular reference errors", function()
  local t = {}
  t.self = t
  local ok = pcall(json.encode, t)
  H.falsy(ok)
end)

H.test("decode number formats", function()
  H.eq(json.decode("3.14"), 3.14)
  H.eq(json.decode("-5"), -5)
  H.eq(json.decode("0"), 0)
end)

H.test("decode whitespace tolerance", function()
  H.eq(json.decode("  {  \"a\" : 1 }  ").a, 1)
end)

H.test("invalid literal errors", function()
  local ok = pcall(json.decode, "tru")
  H.falsy(ok)
end)

H.test("unexpected char errors", function()
  local ok = pcall(json.decode, "{a:1}")
  H.falsy(ok)
end)

H.test("empty string decode errors", function()
  local ok = pcall(json.decode, "")
  H.falsy(ok)
end)

H.test("script.json decodes and is a table", function()
  local f = assert(io.open("scripts/script.json", "r"))
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(json.decode, content)
  H.truthy(ok, "script.json should parse")
  H.eq(type(data), "table")
  H.eq(type(data.nodes), "table")
end)

H.finish()
