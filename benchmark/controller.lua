local diva   = require 'diva'
local ngx    = ngx

module(...)


------------------
-- GET /case_a
------------------
case_a = diva.build(function(ep)

  ep:before(function(env)
    env.counter = 0
  end)

  ep:perform(function(env)
    local counter = env.counter

    for _=1,10000 do
      counter = counter + 1
    end

    return 200, counter - 1
  end)

end)


------------------
-- GET /case_b
------------------
case_b = diva.build(function(ep)

  ep:before(function(env)
    env.counter = 0
  end)

  -- Add 10 separate before filters
  for _=1,10 do
    ep:before(function(env)
      local counter = env.counter
      for _=1,1000 do
        counter = counter + 1
        env.counter = counter
      end
    end)
  end

  ep:perform(function(env)
    return 200, env.counter - 1
  end)

end)

------------------
-- GET /plain
------------------
function plain()
  local counter = 0

  for _=1,10000 do
    counter = counter + 1
  end
  ngx.print(counter - 1)

  return ngx.exit(200)
end
