-- Lua core locals
local setmetatable  = setmetatable
local type          = type
local concat        = table.concat

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
  local status, body = fun(...)

  if status then
    self.status = status
  end

  if body then
    self.body = body
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


      --   domain = "; domain=" + value[:domain] if value[:domain]
      --   path = "; path=" + value[:path] if value[:path]
      --   max_age = "; max-age=" + value[:max_age] if value[:max_age]
      --   expires = "; expires=" +
      --     rfc2822(value[:expires].clone.gmtime) if value[:expires]
      --   secure = "; secure" if value[:secure]
      --   httponly = "; HttpOnly" if value[:httponly]
      --   value = value[:value]
      -- end
      -- value = [value] unless Array === value
      -- cookie = escape(key) + "=" +
      --   value.map { |v| escape v }.join("&") +
      --   "#{domain}#{path}#{max_age}#{expires}#{secure}#{httponly}"