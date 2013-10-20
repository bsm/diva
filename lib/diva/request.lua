-- Lua core locals
local setmetatable  = setmetatable
local downcase      = string.lower
local gmatch        = string.gmatch
local type          = type

-- Nginx specific locals
local ngx           = ngx
local ngx_req       = ngx.req
local get_uri_args  = ngx_req.get_uri_args
local get_post_args = ngx_req.get_post_args
local get_body_data = ngx_req.get_body_data
local get_headers   = ngx_req.get_headers
local get_method    = ngx_req.get_method
local read_body     = ngx_req.read_body
local discard_body  = ngx_req.discard_body

local _M = {}

------------------
-- LOCAL HELPERS
------------------

local ensure_body = function(self)
  if not self._memo.body_read then
    self._memo.body_read = true
    read_body()
  end
end

local pick_ip = function(str, first, match)
  if type(str) ~= "string" then
    return
  end

  local picked
  for addr in gmatch(str, "[^,%s]+") do
    if addr ~= "127.0.0.1" and addr ~= "localhost" and addr ~= "unix" and
        not addr:find("^192%.168%.") and not addr:find("^10%.") and
        not addr:find("^unix%:") then
      if first or addr == match then
        return addr
      else
        picked = addr
      end
    end
  end

  return picked
end

---------------
-- PUBLIC API
---------------

-- Create a new request
_M.new = function(self)
  return setmetatable({ _memo = {} }, { __index = self })
end

-- The methos e.q. GET or POST
_M.method = function(self)
  if not self._method then
    self._method = get_method()
  end

  return self._method
end

-- The client IP
_M.ip = function(self)
  if not self._ip then
    local var = ngx.var
    self._ip = pick_ip(var.remote_addr, true) or
      pick_ip(var.http_x_forwarded_for, false, var.http_client_ip) or
      var.remote_addr
  end

  return self._ip
end

-- The user agent
_M.user_agent = function(self)
  return ngx.var.http_user_agent
end

-- The referer
_M.referer = function(self)
  return ngx.var.http_referer
end

-- The full request path, e.q. /foo/bar?k=v
_M.fullpath = function(self)
  return ngx.var.uri .. ngx.var.is_args .. (ngx.var.args or "")
end

-- The request path without query string e.q. /foo/bar
_M.path = function(self)
  return ngx.var.uri
end

-- The GET query string e.q. a=1&b=2
_M.query_string = function(self)
  return ngx.var.args
end

-- GET params
_M.params = function(self)
  if not self._params then
    self._params = get_uri_args()
  end

  return self._params
end

-- POST params
_M.post_params = function(self)
  if not self._post_params then
    ensure_body(self)
    self._post_params = get_post_args()
  end

  return self._post_params
end

-- Plain request body
_M.body = function(self)
  if not self._memo.body then
    ensure_body(self)
    self._memo.body = true
    self._body = get_body_data()
  end

  return self._body
end

-- Discard the request body unless read
_M.flush = function(self)
  if not self._memo.body_read then
    self._memo.body_read = true
    self._memo.body = true
    discard_body()
  end
end

-- Request headers
_M.headers = function(self)
  if not self._headers then
    self._headers = get_headers()
  end

  return self._headers
end

-- Read a single header, by (underscored, lowercase) name
_M.header = function(self, name)
  return ngx.var["http_" .. downcase(name):gsub("-", "_")]
end

-- Read a single cookie value
_M.cookie = function(self, name)
  return ngx.var["cookie_" .. downcase(name):gsub("-", "_")]
end

return _M