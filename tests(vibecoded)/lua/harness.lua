local H = {}
H.passed = 0
H.failed = 0
H.failures = {}
H.xpassed = 0

local function caller_name()
  return debug.getinfo(3, "n").name or "?"
end

function H.test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    H.passed = H.passed + 1
    io.write("  [ok]   " .. name .. "\n")
  else
    H.failed = H.failed + 1
    table.insert(H.failures, { name = name, err = err })
    io.write("  [FAIL] " .. name .. "\n    " .. tostring(err):gsub("\n", "\n    ") .. "\n")
  end
end

-- Expected-failure test: documents a known bug. Counts as a skip while it
-- fails, and as a failure if it unexpectedly passes (bug fixed but not the test).
function H.xfail(name, fn, why)
  local ok, err = pcall(fn)
  if ok then
    H.failed = H.failed + 1
    table.insert(H.failures, { name = name, err = "expected to fail (known bug) but PASSED" })
    io.write("  [XPASS] " .. name .. "\n    expected failure, got pass. Fix the test?\n")
  else
    H.xpassed = H.xpassed + 1
    io.write("  [XF]   " .. name .. " (known bug: " .. tostring(why or err) .. ")\n")
  end
end

function H.eq(a, b, msg)
  if a ~= b then
    error((msg or "eq") .. ": expected " .. tostring(a) .. " == " .. tostring(b))
  end
end

function H.ne(a, b, msg)
  if a == b then
    error((msg or "ne") .. ": expected " .. tostring(a) .. " ~= " .. tostring(b))
  end
end

function H.truthy(v, msg)
  if not v then error((msg or "truthy") .. ": expected truthy, got " .. tostring(v)) end
end

function H.falsy(v, msg)
  if v then error((msg or "falsy") .. ": expected falsy, got " .. tostring(v)) end
end

function H.isnil(v, msg)
  if v ~= nil then error((msg or "isnil") .. ": expected nil, got " .. tostring(v)) end
end

function H.tableeq(a, b, msg)
  local function deq(x, y, path)
    if type(x) ~= type(y) then
      error("type mismatch at " .. path .. ": " .. type(x) .. " vs " .. type(y))
    end
    if type(x) ~= "table" then
      if x ~= y then error("value mismatch at " .. path .. ": " .. tostring(x) .. " vs " .. tostring(y)) end
      return
    end
    for k, v in pairs(x) do
      deq(v, y[k], path .. "." .. tostring(k))
    end
    for k in pairs(y) do
      if x[k] == nil then error("missing key at " .. path .. "." .. tostring(k)) end
    end
  end
  deq(a, b, msg or "$")
end

function H.matches(str, pat, msg)
  if not tostring(str):match(pat) then
    error((msg or "matches") .. ": '" .. tostring(str) .. "' does not match '" .. pat .. "'")
  end
end

function H.near(a, b, eps, msg)
  eps = eps or 0.001
  if math.abs(a - b) > eps then
    error((msg or "near") .. ": " .. tostring(a) .. " not near " .. tostring(b))
  end
end

function H.finish()
  io.write(string.format("\n%d passed, %d failed, %d expected-failures\n", H.passed, H.failed, H.xpassed))
  for _, f in ipairs(H.failures) do
    io.write(string.format("FAILED: %s\n  %s\n", f.name, f.err))
  end
  os.exit(H.failed > 0 and 1 or 0)
end

function H.describe(name)
  io.write("\n== " .. name .. " ==\n")
end

return H
