-- Lua core locals
local setmetatable  = setmetatable
local downcase      = string.lower

-- Nginx specific locals
local get_uri_args  = ngx.req.get_uri_args
local get_post_args = ngx.req.get_post_args
local get_body_data = ngx.req.get_body_data
local get_headers   = ngx.req.get_headers
local read_body     = ngx.req.read_body
local vars          = ngx.var

module(...)

------------------
-- LOCAL HELPERS
------------------

local ensure_body = function(self)
  if not self._memo.body_read then
    self._memo.body_read = true
    read_body()
  end
end

---------------
-- PUBLIC API
---------------

-- Create a new request
function new(self)
  return setmetatable({ _memo = {} }, { __index = self })
end

-- The full request path, e.q. /foo/bar?k=v
function fullpath(self)
  return vars.uri .. vars.is_args .. vars.args
end

-- The request path without query string e.q. /foo/bar
function path(self)
  return vars.uri
end

-- The GET query string e.q. a=1&b=2
function query_string(self)
  return vars.args
end

-- GET params
function params(self)
  if not self._params then
    self._params = get_uri_args()
  end

  return self._params
end

-- POST params
function post_params(self)
  if not self._post_params then
    ensure_body(self)
    self._post_params = get_post_args()
  end

  return self._post_params
end

-- Plain request body
function body(self)
  if not self._memo.body then
    ensure_body(self)
    self._memo.body = true
    self._body = get_body_data()
  end

  return self._body
end

-- Request headers
function headers(self)
  if not self._headers then
    self._headers = get_headers()
  end

  return self._headers
end

-- Read a single header, by (underscored, lowercase) name
function header(self, name)
  return vars["http_" .. downcase(name):gsub("-", "_")]
end

-- Read a single cookie value
function cookie(self, name)
  return vars["cookie_" .. downcase(name):gsub("-", "_")]
end



