package.path  = './spec/?.lua;./spec/support/?.lua;./lib/?.lua;;' .. package.path
local fakengx = require('fakengx')

_G['ngx'] = fakengx:new()

context('diva', function()

  before(function()
    body_read_count = 0
    ngx.req.get_uri_args  = function() return { k = 1 } end
    ngx.req.get_post_args = function() return { k = 2 } end
    ngx.req.get_body_data = function() return "BODY" end
    ngx.req.read_body     = function() body_read_count = body_read_count + 1 end
    ngx.req.get_headers   = function() return { ['x_custom'] = "HEADER" } end
    ngx.var.remote_addr   = "1.2.3.4"
    ngx.var.uri     = "/foo/bar"
    ngx.var.args    = "a=1&b=2"
    ngx.var.is_args = "?"
    ngx.var.http_x_custom = "HEADER"
    ngx.var.cookie_custom = "COOKIE"
    ngx.var.http_user_agent = "curl/1.0"
    ngx.var.http_referer = "http://original.host/path"
  end)

  after(function()
    for k,_ in pairs(ngx.header) do ngx.header[k] = nil end
    ngx._exit  = nil
    ngx._body  = ''
  end)

  context('main', function()

    before(function()
      diva = require('diva')
    end)

    it('should build endpoints', function()
      local runner = diva.build(function(ep)
        ep:before(function(_) return nil end)
      end)
      assert_type(runner, "function")
      runner()
      assert_equal(ngx._exit, 200)
    end)

  end)

  context('request', function()

    before(function()
      request = require('diva.request'):new()
    end)

    it('should read the method', function()
      assert_equal(request:method(), "GET")
    end)

    it('should read the request path', function()
      assert_equal(request:path(), "/foo/bar")
    end)

    it('should read the full path', function()
      assert_equal(request:fullpath(), "/foo/bar?a=1&b=2")
      ngx.var.is_args = ""
      ngx.var.args = nil
      assert_equal(request:fullpath(), "/foo/bar")
    end)

    it('should parse the IP', function()
      assert_equal(request:ip(), "1.2.3.4")
      request._ip = nil
      ngx.var.remote_addr = "127.0.0.1, 5.6.7.8"
      assert_equal(request:ip(), "5.6.7.8")
      request._ip = nil
      ngx.var.remote_addr = "localhost , unix:/tmp/proxy.sock, 192.168.1.1, 20.10.5.1, 9.8.7.6"
      assert_equal(request:ip(), "20.10.5.1")
      request._ip = nil
      ngx.var.remote_addr = "127.0.0.1"
      ngx.var.http_x_forwarded_for = "1.2.3.4, 5.6.7.8, 9.8.7.6, 127.0.0.1"
      assert_equal(request:ip(), "9.8.7.6")
      request._ip = nil
      ngx.var.http_client_ip = "5.6.7.8"
      assert_equal(request:ip(), "5.6.7.8")
      request._ip = nil
      ngx.var.http_x_forwarded_for = nil
      assert_equal(request:ip(), "127.0.0.1")
    end)

    it('should read the user agent', function()
      assert_equal(request:user_agent(), "curl/1.0")
    end)

    it('should read the referer', function()
      assert_equal(request:referer(), "http://original.host/path")
    end)

    it('should read the query string', function()
      assert_equal(request:query_string(), "a=1&b=2")
    end)

    it('should read & memoize GET params', function()
      assert_nil(request._params)

      assert_type(request:params(), "table")
      assert_type(request._params, "table")
    end)

    it('should read & memoize POST params', function()
      assert_nil(request._post_params)
      assert_nil(request._memo.body_read)

      assert_type(request:post_params(), "table")
      assert_type(request._post_params, "table")
      assert_true(request._memo.body_read)
    end)

    it('should read & memoize plain body', function()
      assert_nil(request._body)
      assert_nil(request._memo.body)
      assert_nil(request._memo.body_read)

      assert_equal(request:body(), "BODY")
      assert_equal(request._body, "BODY")
      assert_true(request._memo.body)
      assert_true(request._memo.body_read)
    end)

    it('should read body once', function()
      assert_equal(request:body(), "BODY")
      assert_type(request:post_params(), "table")
      assert_equal(request:body(), "BODY")
      assert_type(request:post_params(), "table")

      assert_equal(body_read_count, 1)
    end)

    it('should flush requests', function()
      assert_nil(request:flush())
      assert_nil(request:body()) -- Discarded
      assert_equal(body_read_count, 0)
    end)

    it('should read & memoize headers', function()
      assert_nil(request._headers)

      assert_type(request:headers(), "table")
      assert_type(request._headers, "table")
    end)

    it('should read individual headers', function()
      assert_equal(request:header("x_custom"), "HEADER")
    end)

    it('should read individual cookies', function()
      assert_equal(request:cookie("custom"), "COOKIE")
    end)

  end)

  context('response', function()
    before(function()
      response = require('diva.response'):new()
    end)

    it('should have defaults', function()
      assert_equal(response.headers, ngx.header)
      assert_equal(response.body, '')
      assert_nil(response.status)
    end)

    it('should read/write content type', function()
      assert_nil(response:content_type())
      response:content_type("text/plain")
      assert_equal(response:content_type(), "text/plain")
    end)

    it('should parse endpoint callback results', function()
      response:parse(function() end)
      assert_nil(response.status)
      assert_equal(response.body, "")

      response:parse(function() return 204 end)
      assert_equal(response.status, 204)
      assert_equal(response.body, "")

      response:parse(function(i) return i, "Forbidden" end, 403)
      assert_equal(response.status, 403)
      assert_equal(response.body, "Forbidden")

      response:parse(function() return 200, { ["X-Key-A"] = 1, ["X-Key-B"] = 2 }, "Hello" end)
      assert_equal(response.status, 200)
      assert_equal(response.body, "Hello")
      assert_equal(response.headers["X-Key-A"], 1)
      assert_equal(response.headers["X-Key-B"], 2)
    end)

    it('should set cookies', function()
      assert_nil(response.headers['Set-Cookie'])

      local res = response:set_cookie("a key", "a value")
      assert_equal(res, "a+key=a+value")

      assert_type(response.headers['Set-Cookie'], "table")
      assert_equal(#response.headers['Set-Cookie'], 1)
      assert_equal(response.headers['Set-Cookie'][1], res)
    end)

    it('should set complex cookies', function()
      local res = response:set_cookie("a key", {"a", "b & c", "d"}, {
        domain  = ".host",
        path    = "/path",
        expires = 1313131313,
        max_age = 3600,
        secure  = true,
        http_only = true
      })
      assert_equal(res, "a+key=a&b+%26+c&d; domain=.host; path=/path; max_age=3600; expires=Fri, 12-Aug-2011 06:41:53 GMT; secure; HttpOnly")
    end)

    it('should render', function()
      response.body = "Hello"
      assert_equal(response:render(), 200)
      assert_equal(ngx._body, "Hello")
      assert_equal(ngx.status, 200)

      response.body   = "Forbidden"
      response.status = 403
      assert_equal(response:render(), 403)
      assert_equal(ngx._body, "HelloForbidden")
      assert_equal(ngx.status, 403)
    end)

  end)

  context('endpoint', function()

    before(function()
      endpoint = require('diva.endpoint'):new()
      blank1 = function() end
      blank2 = function() end
    end)

    it('should accept before filters', function()
      endpoint:before(blank1)
      endpoint:before(blank2)
      assert_equal(#endpoint._before, 2)
      assert_equal(endpoint._before[1], blank1)
      assert_equal(endpoint._before[2], blank2)
    end)

    it('should accept after filters', function()
      endpoint:after(blank1)
      endpoint:after(blank2)
      assert_equal(#endpoint._after, 2)
      assert_equal(endpoint._after[1], blank2)
      assert_equal(endpoint._after[2], blank1)
    end)

    it('should accept around filters', function()
      endpoint:around(blank1, blank2)
      assert_equal(#endpoint._before, 1)
      assert_equal(endpoint._before[1], blank1)
      assert_equal(#endpoint._after, 1)
      assert_equal(endpoint._after[1], blank2)
    end)

    it('should accept perform blocks', function()
      endpoint:perform(f1)
      endpoint:perform(f2)
      assert_equal(endpoint._perform, f2)
    end)

    it('should run (with fallbacks)', function()
      endpoint:run()
      assert_equal(ngx._exit, 200)
      assert_equal(#ngx.header, 0)
      assert_equal(ngx._body, '')
    end)

    it('should run (with filters)', function()
      endpoint:before(function(env) env.var = env.req:params()['k'] or 0 end)
      endpoint:before(function(env)
        env.res.headers['X-Key-A'] = 'v1'
        env.var = env.var + 5
      end)
      endpoint:before(function(env) env.var = env.var * 2 end)
      endpoint:perform(function(env)
        env.res.headers['X-Key-B'] = 'v2'
        return 201, env.var - 1
      end)
      endpoint:after(function(env) env.res.body = env.res.body .. "x" end)
      endpoint:run()

      assert_equal(ngx._exit, 201)
      assert_equal(ngx.header['X-Key-A'], 'v1')
      assert_equal(ngx.header['X-Key-B'], 'v2')
      assert_equal(ngx._body, '11x')
    end)

    it('should run (with custom opts)', function()
      endpoint:before(function(env) return 400 + env.a end)
      endpoint:run({ a = 3 })
      assert_equal(ngx._exit, 403)
    end)

    it('should allow stop-gaps (through filters)', function()
      local ran = {}
      endpoint:before(function(env) env.var = 10 end)
      endpoint:before(function(env) return 500 end)
      endpoint:before(function(env) ran.before = true end) -- won't be run
      endpoint:perform(function(env) return 200, nil, env.var end) -- won't be run
      endpoint:after(function(env)  ran.after = true end) -- will be run
      endpoint:run()

      assert_equal(ngx._exit, 500)
      assert_equal(ngx._body, '')
      assert_nil(ran.before)
      assert_true(ran.after)
    end)

    it('should catch and handle errors', function()
      local ran = {}
      local rescued =
      endpoint:before(function(env) ran.before = true end)
      endpoint:perform(function(env) error("custom message") end)
      endpoint:after(function(env) rescued = env.err; ran.after = true end)

      local ok, err = pcall(endpoint.run, endpoint)
      assert_false(ok)
      assert_not_nil(err:find("custom message"))
      assert_not_nil(rescued:find("custom message"))
      assert_true(#err > #rescued)

      assert_true(ran.before)
      assert_true(ran.after)
    end)

  end)

end)
