-- Mock of the C++ engine globals that the Lua scripts call.
-- Lets us load the real scripts without a display.

local M = {}

M.state = {
  layers = {},
  layer_order = {},
  audio_sounds = {},
  audio_played = {},
  next_sound_id = 0,
  registered = {},
  switches = {},
  settings = { fullscreen = false, vsync = false, volume = 1.0, frame_limit = 0 },
  fucked = false,
  texture_idx = 1,
  screen_w = 1920,
  screen_h = 1080,
  loaded_textures = {},   -- path -> {idx=...} or invalid
  image_dims = {},        -- path -> {w,h}
  calls = {},             -- log of all engine calls
}

function M.reset()
  local s = M.state
  s.layers = {}
  s.layer_order = {}
  s.audio_sounds = {}
  s.audio_played = {}
  s.next_sound_id = 0
  s.registered = {}
  s.switches = {}
  s.settings = { fullscreen = false, vsync = false, volume = 1.0, frame_limit = 0 }
  s.fucked = false
  s.texture_idx = 1
  s.loaded_textures = {}
  s.image_dims = {}
  s.calls = {}
end

function M.log(name, ...)
  table.insert(M.state.calls, { name, ... })
end

-- TextGooner mock ------------------------------------------------------------
local Gooner = {}
Gooner.__index = Gooner

function Gooner:measureText(text)
  return (#(text or "") * 7)
end

function Gooner:getLineHeight()
  return 32
end

function M.gooner(path, size)
  return setmetatable({ path = path, size = size }, Gooner)
end

-- Element mock --------------------------------------------------------------
local function newElement(kind)
  return {
    kind = kind,
    click = nil,
    revealing = false,
    onClick = function(self, fn) self.click = fn end,
    reveal = function(self, speed) self.revealing = true; self.speed = speed end,
    showAll = function(self) self.revealing = false end,
    isRevealing = function(self) return self.revealing end,
    setFrac = function() end,
  }
end

-- Layer mock ----------------------------------------------------------------
function M.layer(name)
  local layer = {
    name = name,
    visible = true,
    items = {},
    clear = function(self) self.items = {} end,
    addTextF = function(self, gooner, text, x, y, color, z)
      local e = newElement("text")
      e.text = text; e.x = x; e.y = y; e.color = color; e.z = z
      table.insert(self.items, e)
      return e
    end,
    addRectF = function(self, gooner, x, y, w, h, color, z)
      local e = newElement("rect")
      e.x = x; e.y = y; e.w = w; e.h = h; e.color = color; e.z = z
      table.insert(self.items, e)
      return e
    end,
    addImageF = function(self, gooner, tex, x, y, w, h, color, z)
      local e = newElement("image")
      e.tex = tex; e.x = x; e.y = y; e.w = w; e.h = h; e.color = color; e.z = z
      table.insert(self.items, e)
      return e
    end,
  }
  return layer
end

-- Audio mock ----------------------------------------------------------------
function M.audio()
  local s = M.state
  return {
    playSound = function(self, path, single)
      s.next_sound_id = s.next_sound_id + 1
      s.audio_sounds[s.next_sound_id] = path
      table.insert(s.audio_played, { path = path, single = single, id = s.next_sound_id })
      return s.next_sound_id
    end,
    stopSound = function(self, id)
      s.audio_sounds[id] = nil
    end,
    stopAllSounds = function(self)
      s.audio_sounds = {}
    end,
    setVolume = function(self, v)
      s.settings.volume = v
    end,
  }
end

-- Install all globals into _G -------------------------------------------------
function M.install()
  M.reset()
  local s = M.state
  local g = _G

  g.getTextGooner = function(path, size)
    return M.gooner(path, size)
  end
  g.getRectGooner = function() return { kind = "rect" } end
  g.getImageGooner = function() return { kind = "image" } end
  g.getAudioEngine = function() return M.audio() end

  g.loadTexture = function(path)
    local t = s.loaded_textures[path]
    if t == nil then
      if path and path:match("missing") then
        t = { idx = 65535 }
      else
        s.texture_idx = s.texture_idx + 1
        t = { idx = s.texture_idx }
      end
      s.loaded_textures[path] = t
    end
    M.log("loadTexture", path)
    return t
  end

  g.getImageWidth = function(path)
    local d = s.image_dims[path] or { 100, 100 }
    return d[1]
  end
  g.getImageHeight = function(path)
    local d = s.image_dims[path] or { 100, 100 }
    return d[2]
  end
  g.setImageDims = function(path, w, h)
    s.image_dims[path] = { w, h }
  end

  g.getScreenWidth = function() return s.screen_w end
  g.getScreenHeight = function() return s.screen_h end

  g.addUILayer = function(name)
    local l = M.layer(name)
    s.layers[name] = l
    table.insert(s.layer_order, name)
    M.log("addUILayer", name)
    return l
  end
  g.getUILayer = function(name)
    return s.layers[name]
  end
  g.addSceneLayer = function(name)
    local l = M.layer(name)
    s.layers["scene_" .. name] = l
    M.log("addSceneLayer", name)
    return l
  end
  g.getSceneLayer = function(name)
    return s.layers["scene_" .. name]
  end

  g.setFont = function(path, size) M.log("setFont", path, size) end
  g.setFullscreen = function(v) s.settings.fullscreen = v; M.log("setFullscreen", v) end
  g.setVsync = function(v) s.settings.vsync = v; M.log("setVsync", v) end
  g.setVolume = function(v) s.settings.volume = v; M.log("setVolume", v) end
  g.setFrameLimit = function(v) s.settings.frame_limit = v; M.log("setFrameLimit", v) end
  g.fuckOff = function() s.fucked = true; M.log("fuckOff") end

  g.register = function(name, fn) s.registered[name] = fn end
  g.switchTo = function(name)
    table.insert(s.switches, name)
    M.log("switchTo", name)
  end

  g.applySettings = function() end
  g.loadSettings = function() end
  g.saveSettings = function() return true end
  g.Settings = { fullscreen = false, volume = 1.0, framelimit = -1 }
end

-- Load a module and expose its locals -----------------------------------------
-- Reads file content, appends `return { ... }` listing names, executes it.
-- The appended return runs in the same chunk scope so locals are accessible.
function M.load_module(path, exports, extra_code)
  local f = assert(io.open(path, "r"))
  local src = f:read("*a")
  f:close()
  local append = extra_code or ""
  append = append .. "\nreturn { "
  for _, name in ipairs(exports) do
    append = append .. name .. " = " .. name .. ", "
  end
  append = append .. " }"
  local chunk, err = load(src .. append, "@" .. path, "t", _G)
  assert(chunk, "failed to parse " .. path .. ": " .. tostring(err))
  return chunk()
end

-- A gooner whose width function is settable (for wrap tests)
function M.custom_gooner(measure_fn)
  local g = {}
  g.measureText = function(self, text)
    return measure_fn(text or "")
  end
  g.getLineHeight = function() return 32 end
  return g
end

return M
