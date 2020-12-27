--[[
    Powerup class
]]
Powerup = Class{}

--[[
    A simple init function that takes a skin as an argument
    to generate different powerup image.
]]
function Powerup:init(skin, x, y)
    self.width = 16
    self.height = 16
    -- spawn our powerup randomly from top
    self.x = x
    self.y = y
    -- use to determine if the player gets the powerup 
    self.inPlay = true
    -- Variables for powerups speed in  our game and
    -- we want our powerups to fall down
    self.dx = 0
    self.dy = 20
    -- to assign what powerup to render
    self.skin = skin
end

--[[
    A function that takes an argument,in this case only with a paddle,
    and return true if a collison between the powerups and the 
    argument occurs.  
]]

function Powerup:collides(target)
   -- first, check to see if the left edge of either is farther to the right
    -- than the right edge of the other
    if self.x > target.x + target.width or target.x > self.x + self.width then
        return false
    end

    -- then check to see if the bottom edge of either is higher than the top
    -- edge of the other
    if self.y > target.y + target.height or target.y > self.y + self.height then
        return false
    end 

    -- if the above aren't true, they're overlapping
    return true
end

function Powerup:update(dt)
    
    if self.x > 0 and self.y > 0 then
        self.inplay = true
    end
    
    if self.inplay then
        -- Sincce self.dx = 0 it will not move left or right
        self.x = self.x + self.dx * dt
        -- And our powerup will move slowly downward directly
        self.y = self.y + self.dy * dt 
    end
end

function Powerup:render()
    if self.inplay then
        -- gTexture is our global texture for all blocks
        love.graphics.draw(gTextures['main'], gFrames['powerups'][self.skin],
            self.x, self.y)
    end
end
