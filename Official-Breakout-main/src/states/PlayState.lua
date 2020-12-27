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
    self.ball = params.ball
    self.level = params.level

    self.recoverPoints = 5000

    -- give ball random starting velocity
    self.ball.dx = math.random(-200, 200)
    self.ball.dy = math.random(-50, -60)
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
    self.ball:update(dt)

    for k, ball in pairs(self.balls) do

       ball:update(dt)

       if ball:collides(self.paddle) then
           -- raise ball above paddle in case it goes below it, then reverse dy
           ball.y = self.paddle.y - 8
           ball.dy = -ball.dy

           --
           -- tweak angle of bounce based on where it hits the paddle
           --

           -- if we hit the paddle on its left side while moving left...
           if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
               ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))

           -- else if we hit the paddle on its right side while moving right...
           elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
               ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
           end
           gSounds['paddle-hit']:play()
       end
       -- remove ball
       if ball.y> VIRTUAL_HEIGHT then
          table.remove(self.ball, k)
        end
    -- collision detection for our powerup
    for k, powers in pairs(self.powerup) then
      powers:update(dt)
      if powers:collides(self.paddle) then
        --clamp the position of powerup
        powers.y = self.paddle.y - 16
        --splays sound on hit
        gSounds['paddle-hit']play()
        --remove it right after collision with paddle
        table.remove(self.powerup, k)
        if powers.skin == 9 then
          --add 2 balls after collision
          for i = i, 2 do
            -- create new balls with properties of first balls
            multiBall = Ball()
            multiBall.skin = math.math.random(7)
            multiBall.x= self.ball[1].x
            multiBall.y= self.ball[1].y
            multiBall.dy= self.ball[1].dy + math.math.random(-15, 15)
            multiBall.dx= self.ball[1].dx + math.math.random(-10, 10)
            table.insert(self.ball, multiBall)
          end
        elseif power.skin == 10 then
          self.keys = self.keys + 1
        end
        -- remove powerup when it reaches bottom
        if powers.y> VIRTUAL_HEIGHT then
          table.remove(self.powerup, k)
        end
      end
    -- detect collision across all bricks with the ball
    for k, brick in pairs(self.bricks) do

        -- only check collision if we're in play
        if brick.inPlay and self.ball:collides(brick) then

            -- add to score
            self.score = self.score + (brick.tier * 200 + brick.color * 25)

            -- trigger the brick's hit function, which removes it from play
            brick:hit()

            -- if we have enough points, recover a point of health
            if self.score > self.recoverPoints then
                -- can't go above 3 health
                self.health = math.min(3, self.health + 1)

                -- multiply recover points by 2
                self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                 -- PADDLE SIZE UPDATE: if gains certain amount of points, then paddle EXPANDS.
                if self.paddle.size < 3 then
                    self.paddle.size = self.paddle.size + 1
                    self.paddle.width = self.paddle.width + 32
                end

                -- play recover sound effect
                gSounds['recover']:play()
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
                    recoverPoints = self.recoverPoints
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
            if self.ball.x + 2 < brick.x and self.ball.dx > 0 then

                -- flip x velocity and reset position outside of brick
                self.ball.dx = -self.ball.dx
                self.ball.x = brick.x - 8

            -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
            -- so that flush corner hits register as Y flips, not X flips
            elseif self.ball.x + 6 > brick.x + brick.width and self.ball.dx < 0 then

                -- flip x velocity and reset position outside of brick
                self.ball.dx = -self.ball.dx
                self.ball.x = brick.x + 32

            -- top edge if no X collisions, always check
            elseif self.ball.y < brick.y then

                -- flip y velocity and reset position outside of brick
                self.ball.dy = -self.ball.dy
                self.ball.y = brick.y - 8

            -- bottom edge if no X collisions or top collision, last possibility
            else

                -- flip y velocity and reset position outside of brick
                self.ball.dy = -self.ball.dy
                self.ball.y = brick.y + 16
            end

            -- slightly scale the y velocity to speed up the game, capping at +- 150
            if math.abs(self.ball.dy) < 150 then
                self.ball.dy = self.ball.dy * 1.02
            end

            -- only allow colliding with one brick, for corners
            break
        end
    end

    -- if ball goes below bounds, revert to serve state and decrease health
    if self.ball.y >= VIRTUAL_HEIGHT then
        self.health = self.health - 1
        gSounds['hurt']:play()

        if self.health == 0 then
            gStateMachine:change('game-over', {
                score = self.score,
                highScores = self.highScores
            })
        else

             -- PADDLE SIZE UPDATE: if loses a life, then paddle SHRINKS.
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
                recoverPoints = self.recoverPoints
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
    self.ball:render()

    renderScore(self.score)
    renderHealth(self.health)

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
