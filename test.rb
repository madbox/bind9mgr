# Simple test file. I've use it as: "load 'test.rb'" in irb session.

require 'rubygems'
require 'bind9mgr'
require 'ap'

ap Bind9mgr::VERSION

# z = Bind9mgr::Zone.new
# z.file = '/etc/bind/cloud.ru'
# z.load

# ap z.records

# bc = Bind9mgr::NamedConf.new( '/etc/bind/cloudzones.conf' )
# bc.load
# ap bc

# bc.zones.first.load
# ap bc.zones.first


def new_bc
  bc = Bind9mgr::NamedConf.new( '/etc/bind/myzones.conf' )
  bc.main_ns = 'ns.example.com'
  bc.main_server_ip = '192.168.1.200'
  bc.support_email = 'support@example.com'
  bc.load_with_zones
  bc
end
