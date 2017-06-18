-------------
-- define
-------------
require("config")
require("httpserver")

IO_SWITCH = 5

gpio.mode(IO_SWITCH, gpio.OUTPUT ,  gpio.FLOAT)

-------------
-- wifi
-------------

wifimode = wifi.STATION

if ap_ssid and ap_password then
	print('Setting up WIFI ap...')
	ap_cfg={}
	ap_cfg.ssid = ap_ssid
	ap_cfg.pwd  = ap_password
	wifimode    = wifi.STATIONAP
	wifi.ap.config(ap_cfg)
end

print('Setting up WIFI sta...')
wifi.sta.config(ssid, passwd)

print('Setting up WIFI ...')
wifi.sta.autoconnect(1)
wifi.setmode(wifimode)

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
    print("trigger off")
    gpio.write( IO_SWITCH ,  gpio.LOW )

    res:type('application/json')
    res:send('{"status":"off"}')
end)

httpServer:use('/on', function(req, res)
    print("trigger on")
    gpio.write( IO_SWITCH ,  gpio.HIGH )

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
