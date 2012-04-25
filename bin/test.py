import SimpleHTTPServer
import SocketServer
import os

PORT = 8800
WEBDIR = "/tmp"

class Handler(SimpleHTTPServer.SimpleHTTPRequestHandler):
	def do_GET(self):
                os.chdir(WEBDIR)
		return SimpleHTTPServer.SimpleHTTPRequestHandler.do_GET(self)

try:
        #handler = SimpleHTTPServer.SimpleHTTPRequestHandler
        httpd = SocketServer.TCPServer(("",PORT),Handler)
        print 'dir %s serving at port %s' % (repr(WEBDIR),PORT)
        httpd.serve_forever()
except:
        pass
