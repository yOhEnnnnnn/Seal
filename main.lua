Data = require("data")
gw, gh = Data.display.width, Data.display.height
aw, ah = Data.display.arena_width, Data.display.arena_height

require("engine.object")
require("engine.math.spring")
require("engine.graphics.graphics")
require("engine.graphics.canvas")
require("engine.graphics.camera")
require("engine.game.gameobject")
require("engine.game.group")
require("engine.game.collision")
require("engine.game.physics")
require("engine.game.steering")
require("engine.game.unit")

require("audio")
require("effect")
require("projectile")
require("enemy")
require("player")
require("hud")
require("arena")
require("sidebar")
require("game")

function love.load()
  game = Game()
end

function love.update(dt)
  game:update(dt)
end

function love.draw()
  game:draw()
end

function love.keypressed(key, scancode)
  game:keypressed(key, scancode)
end

function love.mousepressed(x, y, button)
  game:mousepressed(x, y, button)
end
