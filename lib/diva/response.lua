-- Lua core locals
local setmetatable  = setmetatable
local type          = type
local concat        = table.concat
local pairs         = pairs

-- Nginx locals
local print         = ngx.print
local headers       = ngx.header
local escape_uri    = ngx.escape_uri
local cookie_time   = ngx.cookie_time

module(...)

---------------
-- PUBLIC API
---------------

-- Create a new response
function new(self)
  return setmetatable({ headers = headers, body = '' }, { __index = self })
end

-- Parse the response from executing `fun` with arguments
function parse(self, fun, ...)
  local vals = {fun(...)}

  if #vals == 1 then
    self.status = vals[1]
  elseif #vals == 2 then
    self.status = vals[1]
    self.body   = vals[2]
  elseif #vals == 3 then
    self.status = vals[1]
    self.body   = vals[3]
    for k, v in pairs(vals[2]) do
      self.headers[k] = v
    end
  end
end

-- Set or read the content type
function content_type(self, value)
  if value then
    self.headers['Content-Type'] = value
  end

  return self.headers['Content-Type']
end

-- Sets a cookie
function set_cookie(self, name, value, opts)
  local jar  = self.headers['Set-Cookie'] or {}
  local vals = {}
  local opts = opts or {}

  -- Encode values
  if type(value) == "table" then
    for i=1,#value do
      vals[#vals+1] = escape_uri(value[i])
    end
  else
    vals[#vals+1] = escape_uri(value)
  end

  -- Write cookie
  local cookie = escape_uri(name) .. "=" .. concat(vals, "&")
  if opts.domain then
    cookie = cookie .. "; domain=" .. opts.domain
  end
  if opts.path then
    cookie = cookie .. "; path=" .. opts.path
  end
  if opts.max_age then
    cookie = cookie .. "; max_age=" .. opts.max_age
  end
  if opts.expires then
    cookie = cookie .. "; expires=" .. cookie_time(opts.expires)
  end
  if opts.secure then
    cookie = cookie .. "; secure"
  end
  if opts.http_only then
    cookie = cookie .. "; HttpOnly"
  end

  jar[#jar+1] = cookie
  self.headers['Set-Cookie'] = jar
  return cookie
end

-- Render the response
function render(self)
  print(self.body)
  return self.status or 200
end
