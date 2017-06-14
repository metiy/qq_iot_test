-------------
-- define
-------------
dofile("wifi.lua")

IO_SWITCH = 5
IO_BTN_CFG= 3

TMR_WIFI  = 4
TMR_BLINK = 5
TMR_BTN   = 6


--------------------
-- helper
--------------------
function urlDecode(url)
    return url:gsub('%%(%x%x)', function(x)
        return string.char(tonumber(x, 16))
    end)
end

function guessType(filename)
    local contentTypes = {
        ['.css']  = 'text/css', 
        ['.js']   = 'application/javascript', 
        ['.html'] = 'text/html',
        ['.png']  = 'image/png',
        ['.jpg']  = 'image/jpeg'
    }
    for ext, type in pairs(contentTypes) do
        if string.sub(filename, -string.len(ext)) == ext
            or string.sub(filename, -string.len(ext .. '.gz')) == ext .. '.gz' then
            return type
        end
    end
    return 'text/plain'
end

function getStatusText(code)
    local status = {
        [1]   = 'Informational', [2] = 'Success', [3] = 'Redirection', [4] = 'Client Error', [5] = 'Server Error',
        [200] = 'OK',
        [301] = 'Moved Permanently', [302] = 'Found',
        [403] = 'Forbidden', [404] = 'Not Found'
    }
    local msg = status[code] or status[math.floor(code / 100)] or 'Unknow'
    return code .. ' ' .. msg
end


--------------------
-- Response
--------------------
Response = {
    _skt         = nil,
    _type        = nil,
    _status      = nil,
    _redirectUrl = nil,
}

function Response:new(skt)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o._skt = skt
    return o
end

function Response:redirect(url, status)
    status = status or 302

    self:status(status)
    self._redirectUrl = url
    self:send(getStatusText(status))
end

function Response:type(type)
    self._type = type
end

function Response:status(status)
    self._status = status
end

function Response:send(body)
    self._status = self._status or 200
    self._type = self._type or 'text/html'

    local buf = 'HTTP/1.1 ' .. getStatusText(self._status) .. '\r\n'
        .. 'Content-Type: ' .. self._type .. '\r\n'
        .. 'Content-Length:' .. string.len(body) .. '\r\n'
    if self._redirectUrl ~= nil then
        buf = buf .. 'Location: ' .. self._redirectUrl .. '\r\n'
    end
    buf = buf .. '\r\n' .. body

    local function doSend()
        if buf == '' then 
            self:close()
        else
            self._skt:send(string.sub(buf, 1, 512))
            buf = string.sub(buf, 513)
        end
    end
    self._skt:on('sent', doSend)

    doSend()
end

function Response:sendFile(filename)
    if file.exists(filename .. '.gz') then
        filename = filename .. '.gz'
    elseif not file.exists(filename) then
        self:status(404)
        if filename == '404.html' then
            self:send(getStatusText(404))
        else
            self:sendFile('404.html')
        end
        return
    end

    self._status = self._status or 200
    local header = 'HTTP/1.1 ' .. getStatusText(self._status) .. '\r\n'
    
    self._type = self._type or guessType(filename)

    header = header .. 'Content-Type: ' .. self._type .. '\r\n'
    if string.sub(filename, -3) == '.gz' then
        header = header .. 'Content-Encoding: gzip\r\n'
    end
    header = header .. '\r\n'

    print('* Sending ', filename)
    local pos = 0
    local function doSend()
        file.open(filename, 'r')
        if file.seek('set', pos) == nil then
            self:close()
            print('* Finished ', filename)
        else
            local buf = file.read(512)
            pos = pos + 512
            self._skt:send(buf)
        end
        file.close()
    end
    self._skt:on('sent', doSend)
    
    self._skt:send(header)
end

function Response:close()
    self._skt:on('sent', function() end) -- release closures context
    self._skt:on('receive', function() end)
    self._skt:close()
    self._skt = nil
end

--------------------
-- httpServer
--------------------
httpServer = {
    _srv = nil,
    _middleware = {}
}

function httpServer:use(url, callback)
    self._middleware[#self._middleware + 1] = {
        url = url,
        callback = callback
    }
end

function httpServer:close()
    self._srv:close()
    self._srv = nil
end

function httpServer:listen(port)
    self._srv = net.createServer(net.TCP)
    self._srv:listen(port, function(conn)
        conn:on('receive', function(skt, msg)   
            local req = {source = msg, ip = skt:getpeer()}
            local res = Response:new(skt)

            parseHeader(req, res)
            local blocked = nil
            for i = 1, #self._middleware do
                if string.find(req.path, '^' .. self._middleware[i].url .. '$') then
                    if not self._middleware[i].callback(req, res) then
                        blocked = true
                        break
                    end
                end
            end
            if not blocked then staticFile(req, res) end

            collectgarbage()
        end)
    end)
end


function parseHeader(req, res)
    local _, _, method, path, vars = string.find(req.source, '([A-Z]+) (.+)?(.+) HTTP')
    if method == nil then
        _, _, method, path = string.find(req.source, '([A-Z]+) (.+) HTTP')
    end
    local _GET = {}
    if vars ~= nil then
        vars = urlDecode(vars)
        for k, v in string.gmatch(vars, '([^&]+)=([^&]*)&*') do
            _GET[k] = v
        end
    end
    
    req.method = method
    req.query = _GET
    req.path = path
end

function staticFile(req, res)
    local filename = ''
    if req.path == '/' then
        filename = 'index.html'
    else
        filename = string.gsub(string.sub(req.path, 2), '/', '_')
    end

    res:sendFile(filename)
end


-------------------main function-----------------------

gpio.mode(IO_SWITCH, gpio.OUTPUT ,  gpio.FLOAT)
gpio.write(IO_SWITCH, gpio.LOW)
gpio.mode(IO_BTN_CFG, gpio.INT)

gpio.trig(IO_BTN_CFG, 'up', function()
    print("on btn")
end)

-------------
-- wifi
-------------

print('Setting up WIFI...')

wifi.sta.config(ssid, passwd)
wifi.setmode(wifi.STATION)
wifi.sta.autoconnect(1)

status = nil

wifi.sta.eventMonReg(wifi.STA_WRONGPWD, function()
    status = 'STA_WRONGPWD'
    print(status)
end)

wifi.sta.eventMonReg(wifi.STA_APNOTFOUND, function()
    status = 'STA_APNOTFOUND'
    print(status)
end)

wifi.sta.eventMonReg(wifi.STA_CONNECTING, function(previous_State)
    status = 'STA_CONNECTING'
    print(status)
end)

wifi.sta.eventMonReg(wifi.STA_GOTIP, function()
    status = 'STA_GOTIP'
    print(status, wifi.sta.getip())
end)

wifi.sta.eventMonStart(1000)



httpServer:use('/off', function(req, res)
    gpio.write( IO_SWITCH ,  gpio.LOW )
    print("trigger on")

    res:type('application/json')
    res:send('{"status":"off"}')
end)

httpServer:use('/on', function(req, res)
    gpio.write( IO_SWITCH ,  gpio.HIGH )
    print("trigger off")

    res:type('application/json')
    res:send('{"status":"on"}')
end)

gpiolight = { }
gpiolight[0] = "off"
gpiolight[1] = "on"

httpServer:use('/status', function(req, res)
    print("trigger status")

    res:type('application/json')
    res:send('{"status":"' .. gpiolight[gpio.read( IO_SWITCH )] .. '"}')
end)

print("start http server ")
httpServer:listen(80)
