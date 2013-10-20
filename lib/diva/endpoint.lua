-- Lua core locals
local insert        = table.insert
local pairs         = pairs
local setmetatable  = setmetatable
local traceback     = debug.traceback
local xpcall        = xpcall
local error         = error

-- Nginx specific locals
local ngx           = ngx
local exit          = ngx.exit
local log           = ngx.log
local LOG_NOTICE    = ngx.NOTICE
local LOG_ERR       = ngx.ERR

-- Diva locals
local request       = require 'diva.request'
local response      = require 'diva.response'

local _M = {}

-- Constructor, initializes a new endpoint
_M.new = function(self)
  return setmetatable({
    _before = {},
    _after  = {},
  }, { __index = self })
end

-- Attach a `fun` as a before filter
-- Expects `fun` to accept the env as the first argument
_M.before = function(self, fun)
  insert(self._before, fun)
end

-- Attach a `fun` as an after filter
-- Expects `fun` to accept the env as the first argument
_M.after = function(self, fun)
  insert(self._after, 1, fun)
end

-- Attaches two functions as around filter
-- Expects `pre` & `post` functions to accept the env as the first argument
_M.around = function(self, pre, post)
  self:before(pre)
  self:after(post)
end

-- Attach a `fun` as the actual perform block
-- Expects `fun` to accept the env as the first argument
_M.perform = function(self, fun)
  self._perform = fun
end

-- Notice log
_M.notice = function(_, ...)
  log(LOG_NOTICE, ...)
end

-- Error log
_M.err = function(_, ...)
  log(LOG_ERR, ...)
end

-- Run a request cycle
_M.run = function(self, env)

  -- Create an `env`
  local env = env or {}
  local req = request:new()
  local res = response:new()

  env.req = req
  env.res = res

  -- Executes before filters. Parses return values. Stops execution on response.
  for i=1,#self._before do
    res:parse(self._before[i], env)
    if res.status then break end
  end

  -- If before filters were successful (all returned nil), execute the main perform block
  if not res.status and self._perform then
    local ok, val = xpcall(function()
      return res:parse(self._perform, env)
    end, function(e)
      return traceback(e)
    end)

    if not ok then
      env.err = val
    end
  end

  -- If no response was generated, assume default
  if not res.status then
    res.status = 200
  end

  -- Execute after filters
  for i=1,#self._after do
    self._after[i](env)
  end

  -- Re-raise errors
  if env.err then
    error(env.err)
  end

  -- Respond with status
  return exit(res:render())
end

return _M