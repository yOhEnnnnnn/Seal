Audio = Object:extend()

local pitch_pattern = {-1, 0.35, 1, -0.35, 0}

function Audio:init(config)
  self.config = config or Data.audio
  self.events = {}
  for name, settings in pairs(self.config.events) do
    self.events[name] = self:create_event(settings)
  end
end

function Audio:create_event(settings)
  local paths = settings.paths or {settings.path}
  local event = {voices = {}, next_voice = 1, next_pitch = 1, play_count = 0}
  for index = 1, settings.voices or 1 do
    local path = paths[(index - 1) % #paths + 1]
    local source = love.audio.newSource(path, "static")
    source:setVolume((settings.volume or 1) * self.config.master_volume)
    event.voices[#event.voices + 1] = source
  end
  event.pitch_variation = settings.pitch_variation or 0
  return event
end

function Audio:play(name)
  local event = self.events[name]
  if not event then return false end

  local source = event.voices[event.next_voice]
  local pitch = pitch_pattern[event.next_pitch]
  source:stop()
  source:setPitch(1 + pitch * event.pitch_variation)
  source:play()

  event.next_voice = event.next_voice % #event.voices + 1
  event.next_pitch = event.next_pitch % #pitch_pattern + 1
  event.play_count = event.play_count + 1
  return true
end
