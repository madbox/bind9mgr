require 'spec_helper'

describe Bind9mgr::Zone do
  before do
    @test_db_content = %q{$ORIGIN testdomain.com.
$TTL 86400 ; 1 day
@	IN	SOA	testdomain.com. admin@testdomain.com. (
	2011083002	; serial
	14400		; refresh (4 h)
	3600		; retry (1 h)
	2592000		; expire (4w2d)
	600		; minimum (10 minute)
)
		IN	NS	ns.testdomain.com.
testdomain.com.	IN	A	192.168.1.1
sub1		IN	A	192.168.1.2
sub2		IN	A	192.168.1.3
alias1  	IN	CNAME	ns
}

    File.stub(:exists?).with(anything()).and_return(false)
    File.stub(:exists?).with("testdomain.com.db").and_return(true)

    File.stub(:read).with("testdomain.com.db").and_return(@test_db_content)

    @zone = Bind9mgr::Zone.new
    @zone.file = 'testdomain.com.db'
  end

  it "should be instanceable" do
    expect{ Bind9mgr::Zone.new }.not_to raise_error
  end

  it "should fill itself with data on load method call" do
    @zone.load
    @zone.records.count.should > 0
  end

  pending "should fail to generate db file content unless mandatory options filled"
  pending "should raise if wrong rr type specified"
  pending "should not write repeating rrs"
  it "should generate db file content" do
    @zone.load
    cont = @zone.gen_db_content
    cont.should be_kind_of( String )
    cont.match(/#{@zone.origin}/m).should be
  end
  pending "should generate zone entry content"

  it "should add default rrs before generate db content" do
    zone = Bind9mgr::Zone.new( 'example.com', 'example.com.db',
                               { :main_ns => '192.168.1.1',
                                 :secondary_ns => '192.168.1.2',
                                 :main_server_ip => '192.168.1.3',
                                 :support_email => 'qwe@qwe.ru'
                               })
  end

end
