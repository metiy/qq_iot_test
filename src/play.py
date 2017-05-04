#!/usr/bin/python
# coding=utf-8

import redis , json , subprocess
import sys , os , time

def  call_mpc( command ):
    ret = subprocess.Popen( command , stdin = subprocess.PIPE, stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell = True)
    buf = ret.stdout.read()   
    return buf

Usage = '''
help     this message
stat     show player status
play     start play
stop     stop play
>        play next
<        play prev
+        volume +
-        volume -
ip       get ip addr
'''

replys = 'replys'

if __name__ == "__main__":
    rclient = redis.Redis()
    print (rclient)

    while 1:
        msg = rclient.blpop( ['messages'] , 1)
        if msg == None :
            continue

        data = json.loads(msg[1])
        cmd  = data['text'].lower()

        if cmd == u'help':
            print ("help")
            rclient.rpush(replys , Usage)

        elif cmd == u'stat':
            print "stat"
            r = call_mpc("mpc");
            rclient.rpush(replys , r )

        elif cmd == u'>':
            print "next"
            call_mpc("mpc next")
            r = call_mpc("mpc current")
            rclient.rpush(replys , r )

        elif cmd == u'<':
            print "prev"
            call_mpc("mpc prev")
            r = call_mpc("mpc current")
            rclient.rpush(replys , r)

        elif cmd == u'list':
            print "list"
            r = call_mpc("mpc playlist")
            rclient.rpush(replys , r)

        elif cmd[:4] == u'play':
            print "play"
            call_mpc("mpc "+ cmd )
            r = call_mpc("mpc current")
            rclient.rpush(replys , r)

        elif cmd == u'stop':
            print "stop"
            call_mpc("mpc stop")
            r = call_mpc("mpc")
            rclient.rpush(replys,r)

        elif cmd == u'+':
            print 'volume +10'
            call_mpc("mpc volume +10")
            call_mpc("mpc volume | awk -F ':' '{print($2)}' | awk -F '%' '{print($1)}' > /music/volume.mpd" )
            r = call_mpc("mpc volume")
            rclient.rpush(replys,r)

        elif cmd == u'-':
            print 'volume -10'
            call_mpc("mpc volume -10")
            call_mpc("mpc volume | awk -F ':' '{print($2)}' | awk -F '%' '{print($1)}' > /music/volume.mpd" )
            r = call_mpc("mpc volume")
            rclient.rpush(replys , r)

	elif cmd == u'ip':
            print 'get ip'
            c = "ifconfig wlan0 | grep inet | awk '{print $2 \"\\n\" $3 \"\\n\" $4}'"
            r = call_mpc(c)
            rclient.rpush(replys , r)

        else:
            rclient.rpush(replys , "unknow cmd:" + cmd + "\n\n" + Usage)
            print('unknow cmd')




