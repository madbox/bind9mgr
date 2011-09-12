= bind9mgr

https://github.com/madbox/bind9mgr
https://rubygems.org/gems/bind9mgr

== DESCRIPTION:

This gem contains some classes to manage bind9 zone files

== FEATURES/PROBLEMS:

Features:
* zone db file parseing
* named.conf simple parser
* OO data organization
* Simple verifications
* add zone intaeface
* delete zone interface
* automatic zone options management (origin, default NS, default A, "www" CNAME etc)

Please look into specs for more detailed info.

TODO: more configuration features
TODO: more conventions(feedback welcomed!)
TODO: xml mappings for restful APIs

== SYNOPSIS:

  bc = Bind9mgr::NamedConf.new( '/etc/bind/named.conf.local',
                                :main_ns => 'ns1.example.com',
                                :secondary_ns => 'ns2.example.com',
                                :support_email => 'support@example.com',
                                :main_server_ip => '192.168.1.1'
                                )
  bc.load_with_zones
  bc.zones # => [ existing zones ... Bind9mgr::Zone ]
  bc.zones.first.records # => [ records ... Bind9mgr::ResourceRecord ]
  
  bc.add_zone('y_a_zone.org') # adds zone entry with default params
  bc.write_all # rewrites named.conf.local and zone db files (in /etc/bind/zones_db.)
  bc.del_zone!('y_a_zone.org') # immidiately removes db file and zone entry in named.conf.local 

== REQUIREMENTS:

rspec >= 2.6.0
awesome_print
Tested with Ruby 1.9.2

== INSTALL:

gem install bind9mgr

== DEVELOPERS:

After checking out the source, run:

  $ rake newb

This task will install any missing dependencies, run the tests/specs,
and generate the RDoc.

== LICENSE:

(The MIT License)

Copyright (c) 2011 FIX

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
