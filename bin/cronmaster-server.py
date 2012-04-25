#!/bin/env python
#  written by haitao.yao
#  used as master server for contab
import web
import os,sys
from SimpleHTTPServer import SimpleHTTPRequestHandler
from StringIO import StringIO
import urllib
import cgi
import ConfigParser
import time
urls = (
	'/', 'index',
	'/scripts/(.*)', 'file_handler',
	'/scripts', 'dir_handler',
	'/list', 'list_handler',
	'/ok.html', 'ok_handler',
	'/report', 'report_handler',

)

cronmaster_home = os.getenv('CRONMASTER_HOME')
if cronmaster_home == None:
	print "No CRONMASTER_HOME! "
	exit(1)
if not os.path.isdir(cronmaster_home):
	print "CRONMASTER_HOME is not valid dir: %s " % cronmaster_home
	exit(1)
master_config_file = cronmaster_home+"/config/cronmaster.conf"
if not os.path.isfile(master_config_file):
	print "config file for cronmaster, path: %s" % master_config_file
	exit(1)
cf = ConfigParser.ConfigParser()
cf.read(master_config_file)
bind_address=cf.get('server', 'bind')
web_dir=cf.get('storage', 'scripts')
list_dir=cf.get('storage', 'list')
if (web_dir == None) or (not os.path.isdir(web_dir)):
	print 'no scripts config under storage'
	exit(1)
if (list_dir == None) or (not os.path.isdir(list_dir)):
	print "no list dir under storage"
	exit(1)


#web_dir='/Users/haitao/test/scripts'


app = web.application(urls, globals())

class report_handler:
	def POST(self):
		report_log_file=open(cronmaster_home+'/logs/report.' + time.strftime('%Y%m%d', time.localtime()) +'.log', 'a')
		report_message = time.strftime('%Y-%m-%d.%H:%M:%S', time.localtime()) + ' ### ' + web.ctx.ip+' ### ' + str(web.input().message) + '\n'
		report_log_file.write(report_message)
		report_log_file.close()
		return 'ok'

	def GET(self):
		return 'only post is supported'
		

class list_handler:
	def GET(self):
		node_ip=web.ctx.ip
		node_config_file = list_dir + '/' + node_ip +".conf"
		if not os.path.isfile(node_config_file):
			raise web.notfound('no config file for %s' % node_config_file)
		else:
			return open(node_config_file)



class index:
	def GET(self):
		return 'cronmaster running here'
class dir_handler:
	def GET(self):
       		 list = os.listdir(web_dir)
       		 list.sort(key=lambda a: a.lower())
       		 f = StringIO()
       		 displaypath = cgi.escape(urllib.unquote(web_dir))
       		 f.write('<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">')
       		 f.write("<html>\n<title>Directory listing for %s</title>\n" % displaypath)
       		 f.write("<body>\n<h2>Directory listing for %s</h2>\n" % displaypath)
       		 f.write("<hr>\n<ul>\n")
       		 for name in list:
       		     fullname = os.path.join(web_dir, name)
       		     displayname = linkname = name
		     linkname='scripts/' + name
       		     # Append / for directories or @ for symbolic links
       		     if os.path.isdir(fullname):
       		         displayname = name + "/" 
       		         linkname = name + "/" 
       		     if os.path.islink(fullname):
       		         displayname = name + "@" 
       		         # Note: a link to a directory displays with @ and links with /
       		     f.write('<li><a href="%s">%s</a>\n'
       		             % (urllib.quote(linkname), cgi.escape(displayname)))
       		 f.write("</ul>\n<hr>\n</body>\n</html>\n")
       		 length = f.tell()
       		 f.seek(0)
       		 return f
	

class file_handler:
	def GET(self, name):
		os.chdir(web_dir)
		if os.path.isfile(name):
			web.header('Content-type', 'application/octet-stream')
			web.header('Content-Length', os.stat(name).st_size)
			return open(name)
		else:
			raise web.notfound('not found file: %s' % name)

class ok_handler:
	def GET(self):
		return 'ok'

if __name__ == '__main__':
	fakeargv = ["fake", bind_address]
	sys.argv=fakeargv
	app.run()


