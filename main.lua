gw, gh = 480, 270

require("engine.object")
require("engine.math.spring")
require("engine.graphics.graphics")
require("engine.graphics.canvas")
require("engine.game.gameobject")
require("engine.game.group")
levels = require("data.levels")
require("data.bullets")
require("game.game_rules")
require("effect")
require("engine.game.physics")
require("engine.game.steering")
require("engine.game.unit")
require("projectile")
require("enemy")
require("player")
require("shop")
require("game.game")

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
