-- Tests for external/son/src/son.lua (the script format that replaced JSON).
-- The engine evaluates script.son with a `chosen()` env; this suite covers the
-- parser/eval independently so regressions in the format are caught early.
local H = require("tests(vibecoded)/lua/harness")
local M = require("tests(vibecoded)/lua/mock")

M.install()
local son = dofile("external/son/src/son.lua")

local function ev(src, env)
  return son.eval(son.parse(src), env or {})
end

local function get(src, key, env)
  return son.get(ev(src, env), key)
end

H.describe("son.lua parse / eval")

H.test("parses keys and string values", function()
  local t = son.parse([[ { "a": "1" "b": "hello" } ]])
  local e = son.eval(t, {})
  H.eq(son.get(e, "a"), "1")
  H.eq(son.get(e, "b"), "hello")
end)

H.test("all values are strings", function()
  H.eq(get([[ { "n": "42" } ]], "n"), "42")
  H.eq(get([[ { "f": "3.14" } ]], "f"), "3.14")
end)

H.test("nested objects roundtrip via find", function()
  local e = ev([[ { "nodes": { "1": { "text": "hi" } } } ]])
  local nodes = son.find(e, "nodes")
  H.truthy(nodes ~= nil)
  H.eq(son.get(son.find(nodes, "1"), "text"), "hi")
end)

H.test("missing key returns nil", function()
  H.isnil(get([[ { "a": "1" } ]], "nope"))
  H.isnil(son.find(ev([[ { "a": "1" } ]]), "nope"))
end)

H.test("escaped sequences decode", function()
  H.eq(get([[ { "s": "a\nb\t\"c\"\\d" } ]], "s"), "a\nb\t\"c\"\\d")
end)

H.test("; line comments are ignored", function()
  H.eq(get("; garbage comment\n{ \"a\": \"1\" }", "a"), "1")
end)

H.test("# hash comments are ignored", function()
  H.eq(get("# not a define\n{ \"a\": \"1\" }", "a"), "1")
end)

H.test("#define macro replaces an exact whole value", function()
  local src = "#define Q 3\n{ \"a\": \"Q\" \"b\": \"notQ\" }"
  H.eq(get(src, "a"), "3")
  H.eq(get(src, "b"), "notQ")
end)

H.test("unquoted values are silently dropped", function()
  local e = ev([[ { "a": 1 "b": "kept" } ]])
  H.isnil(son.get(e, "a"))
  H.eq(son.get(e, "b"), "kept")
end)

H.describe("son.lua inline Lua (!!)")

H.test("object whose only child is inline evaluates to a string", function()
  H.eq(get([[ { "r": { !!"__lua__": "return '998'" } } ]], "r"), "998")
  H.eq(get([[ { "r": { !!"__lua__": "return 42" } } ]], "r"), "42")
end)

H.test("inline code can call env functions", function()
  local src = [[ { "r": { !!"__lua__": "return myfn(5)" } } ]]
  H.eq(get(src, "r", { myfn = function(x) return x * 2 end }), "10")
end)

H.test("bad inline code raises an error", function()
  local ok = pcall(ev, [[ { "r": { !!"__lua__": "lol(" } } ]])
  H.falsy(ok)
end)

H.describe("son.lua if() branches")

H.test("if(true) body is kept, if(false) body is dropped", function()
  local src = [[ { "a": "1" !"if(true)": { "x": "on" } !"if(false)": { "y": "off" } } ]]
  local e = ev(src)
  H.eq(son.get(e, "x"), "on")
  H.isnil(son.get(e, "y"))
end)

H.test("if() condition reads env variables", function()
  local src = [[ { "a": "1" !"if(owo == "VAR")": { "text": "hello" } } ]]
  H.isnil(get(src, "text", { owo = "dick" }))
  H.eq(get(src, "text", { owo = "VAR" }), "hello")
end)

H.test("if(chosen(...)) with env predicate mirrors the game", function()
  local src = [[
    { "a": "1"
      !"if(chosen("6", "4"))": { "text": "picked 4" }
      !"if(not chosen("6", "4"))": { "text": "not 4" }
    }
  ]]
  local choices = { { node = "6", choice = "4" } }
  local function chosen(nodeId, choice)
    for _, c in ipairs(choices) do
      if tostring(c.node) == tostring(nodeId) and tostring(c.choice) == tostring(choice) then
        return true
      end
    end
    return false
  end
  H.eq(get(src, "text", { chosen = chosen }), "picked 4")
  choices = {}
  H.eq(get(src, "text", { chosen = chosen }), "not 4")
end)

H.test("macros resolve inside if() conditions", function()
  local src = "#define FLAG true\n{ \"a\": \"1\" !\"if(FLAG)\": { \"x\": \"yes\" } }"
  H.eq(get(src, "x"), "yes")
end)

H.test("bad if() condition raises an error", function()
  local ok = pcall(ev, [[ { "a": "1" !"if(true false)": { "x": "y" } } ]])
  H.falsy(ok)
end)

H.describe("son.lua file api")

H.test("parse_file reads the real script.son", function()
  local tree, ok = son.parse_file("scripts/script.son")
  H.truthy(ok)
  H.truthy(tree ~= nil)
end)

H.test("parse_file returns nil,false for missing file", function()
  local t, ok = son.parse_file("no_such.son")
  H.isnil(t)
  H.eq(ok, false)
end)

H.test("eval_file evaluates and returns the root object", function()
  local e, ok = son.eval_file("scripts/script.son", { chosen = function() return false end })
  H.truthy(ok)
  H.eq(son.get(e, "start"), "1")
end)

H.test("dump does not crash on a parsed tree", function()
  local tree, ok = son.parse_file("scripts/script.son")
  H.truthy(ok)
  local ok2 = pcall(son.dump, tree, 0)
  H.truthy(ok2)
end)

H.finish()