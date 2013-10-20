-- Diva locals
local endpoint = require 'diva.endpoint'

module(...)

-- Endpoint builder, Example:
--
--    -- controller.lua
--    local diva = require 'diva'
--
--    module(...)
--
--    endpoint_a = diva.build(function(c)
--      c.before(function(env)
--        env.var = 1
--      end)
--
--      c.before(function(env)
--        env.res.headers['X-Custom'] = 2
--        env.var = env.var + 1
--      end)
--
--      c.perform(function(env)
--        return 200, env.var
--      end)
--    end)
--
--    endpoint_b = diva.build(function(c)
--      c.before(function(env)
--        return 403, "Not Authorized"
--      end)
--
--      c.after(function(env) -- still performed
--        env.res.body = env.res.body + "!"
--      end)
--    end
--
-- In your nginx.conf:
--
--    init_by_lua "controller = require('controller')"
--
--    ...
--
--    location /a {
--      content_by_lua "controller.endpoint_a()";
--    }
--    location /b {
--      content_by_lua "controller.endpoint_b()";
--    }
--
function build(fun)
  local point = endpoint:new(self)
  fun(point)
  return function(opts) return point:run(opts) end
end
