--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

local HIT_BLOCK_COUNT = 20


--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    -- we now make our ball params as a table 
    self.ball = {params.ball}
    self.level = params.level
    self.keys = params.keys
    self.recoverPoints = params.recoverPoints

    self.paddlerecoverPoints = 0
    -- give ball random starting velocity
    self.ball[1].dx = math.random(-200, 200)
    self.ball[1].dy = math.random(-50, -60)
    -- initialize multiball powerup  
    self.powerup = { [1] = Powerup(9, -8, -8)}
    -- a random variable to trigger powerup spawn
    self.hitcount =  math.floor(self.health/3 * HIT_BLOCK_COUNT) 
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)

    for k, ball in pairs(self.ball) do 
        ball:update(dt)
        if ball:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            ball.y = self.paddle.y - 8
            ball.dy = -ball.dy

            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if ball.x < ball.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
               ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
            end

            gSounds['paddle-hit']:play()
        end
        -- remove ball 
        if ball.y > VIRTUAL_HEIGHT then
            table.remove(self.ball, k)
        end

    end

     -- collision detection for our powerup
    for k, powers in pairs(self.powerup) do
        powers:update(dt)
        if powers:collides(self.paddle) then
            -- clamp the position of powerup
            powers.y = self.paddle.y - 16
            -- splays sound on hit  
            gSounds['paddle-hit']:play()
            --remove it right after collision with paddle 
            table.remove(self.powerup, k)
            if powers.skin == 9 then 
                -- add 2 balls after collision
                for i = 1, 2 do
                    -- create new balls with properties of first ball
                    multiBall = Ball()                                     
                    multiBall.skin = math.random(7)
                    multiBall.x = self.ball[1].x
                    multiBall.y = self.ball[1].y
                    multiBall.dy = self.ball[1].dy + math.random(-15,15)
                    multiBall.dx = self.ball[1].dx + math.random(-10,10)
                    table.insert(self.ball, multiBall)
                end
            elseif powers.skin == 10 then
                self.keys = self.keys + 1
            end
        end
        -- remove powerup when it reaches bottom
        if powers.y > VIRTUAL_HEIGHT then
            table.remove(self.powerup, k)
        end
    end

    -- detect collision across all balls 
    for k, ball in pairs(self.ball) do
        -- detect collision across all bricks 
        for k, brick in pairs(self.bricks) do
    
            if brick.inPlay and ball:collides(brick) then

                if brick.locked == true and self.keys >= 1 then
                    brick.inPlay = false
                    self.keys = self.keys - 1
                    gSounds['brick-hit-1']:play()
                    self.score = self.score + 500
                end

                if brick.locked == false then
                    -- add to score
                    self.score = self.score + (brick.tier * 200 + brick.color * 25)
                    -- trigger the brick's hit function, which removes it from play
                    brick:hit()
                else
                    self.hitcount = self.hitcount - 1
                    gSounds['no-select']:play()
                end
            
                self.hitcount = self.hitcount - 1
                -- spawn powerups 
                -- spawn multiball powerup depeneding on no. of hit
                if math.random(self.hitcount) == self.hitcount then                     
                    table.insert(self.powerup, Powerup(9, brick.x, brick.y))
                    self.hitcount =   math.floor(self.health/3 * HIT_BLOCK_COUNT) 
                -- if we have locked bricks then we will spawn key powerup
                elseif (self.level % 3) == 0 and brick.locked == true and math.random(math.floor(self.hitcount/2)) == math.floor(self.hitcount/2)  then    
                    table.insert(self.powerup, Powerup(10, brick.x, brick.y))
                    self.hitcount =   math.floor(self.health/3 * HIT_BLOCK_COUNT) 
                end
                
                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    -- can't go above 3 health
                    self.health = math.min(3, self.health + 1)

                    -- multiply recover points by 2
                    self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                    -- play recover sound effect
                    gSounds['recover']:play()
                end

                self.paddlerecoverPoints = self.paddlerecoverPoints + (brick.tier * 200 + brick.color * 25)
                -- paddle grows everytime we score 1500 additional points 
                if self.paddlerecoverPoints > 100 then
                    gSounds['recover']:play()

                    --paddle grow
                    if self.paddle.size < 4 then
                        self.paddle.size = self.paddle.size + 1
                        self.paddle.width = self.paddle.width + 32
                    end 

                    self.paddlerecoverPoints = 0
                end

                -- go to our victory screen if there are no more bricks left
                if self:checkVictory() then
                    gSounds['victory']:play()

                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        ball = self.ball,
                        recoverPoints = self.recoverPoints,
                        keys = self.keys
                    })
                end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if ball.x + 2 < brick.x and ball.dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif ball.y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(ball.dy) < 150 then
                    ball.dy = ball.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end
    end

    -- if all balls in table is removed, revert to serve state and decrease health
    if #self.ball == 0  then
        self.health = self.health - 1
        gSounds['hurt']:play()

        if self.health == 0 then
            gStateMachine:change('game-over', {
                score = self.score,
                highScores = self.highScores
            })
        else
            -- paddle shrink
            if self.paddle.size > 1 then
                self.paddle.size  = self.paddle.size - 1
                self.paddle.width = self.paddle.width - 32
            end
            gStateMachine:change('serve', {
                paddle = self.paddle,
                bricks = self.bricks,
                health = self.health,
                score = self.score,
                highScores = self.highScores,
                level = self.level,
                recoverPoints = self.recoverPoints,
                keys = self.keys
            })
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()

    for k, ball in pairs(self.ball) do
        ball:render()
    end

    for k, powers in pairs(self.powerup) do
        powers:render()
    end

    renderScore(self.score)
    renderHealth(self.health)
    if (self.level % 3) == 0 then
        renderKeys(self.keys)
    end

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end
