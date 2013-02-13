require 'spec_helper'

describe Bind9mgr::Parser do

  # first rrs are used by index at some tests so dont change their sequence
  let(:test_zone) do
    %Q{$ORIGIN cloud.ru.
$TTL 86400 ; 1 day
@	IN	SOA	cloud.ru. root.cloud.ru. (
	2011083002	; serial
	14400		; refresh (4 h)
	3600		; retry (1 h)
	2592000		; expire (4w2d)
	600		; minimum (10 minute)
)
		IN	NS	ns.cloud.ru.
ns		IN	A	192.168.1.200
nfsstorage	IN	CNAME	ns
mail            IN MX 40 192.168.1.33
www CNAME @
cloud.ru.	IN	A	192.168.1.1
human-txt     TXT 'this is text with spases'

NS ns2.cloud.ru
manager		IN	A	192.168.1.20
director	IN	A	192.168.1.23
directorproxy	IN	A	192.168.1.24
oracle		IN	A	192.168.1.19
vcenter		IN	A	192.168.1.12
esx1		IN	A	192.168.1.2
; some comment
}
  end

  before do
    p = Bind9mgr::Parser.new
    p.parse test_zone
    @result = p.result
  end

  it "should parse test data without errors" do
    expect {
      p = Bind9mgr::Parser.new
      p.parse test_zone
    }.not_to raise_error
  end

  it "should raise exception if there is no parentices in SOA definition" do
    p = Bind9mgr::Parser.new
    expect{
      p.parse %q{ 
@	IN	SOA	cloud.ru. root.cloud.ru. (
	2011083002	; serial
	14400		; refresh (4 h)
	3600		; retry (1 h)
	2592000		; expire (4w2d)
	600		; minimum (10 minute)

}
    }.to raise_error
    expect{
      p.parse %q{ 
@	IN	SOA	cloud.ru. root.cloud.ru. 
	2011083002	; serial
	14400		; refresh (4 h)
	3600		; retry (1 h)
	2592000		; expire (4w2d)
	600		; minimum (10 minute)
)
}
    }.to raise_error
  end
  
  it "should provide Zone with ResourceRecords" do
    @result.should be_kind_of Bind9mgr::Zone
    @result.records.count.should > 0
    @result.records.first.should be_kind_of Bind9mgr::ResourceRecord # in hope that othes wil be the same
  end

  it "should have SOA record as first element of records" do
    @result.records.first.type.should == 'SOA'
  end

  it "should have 7 elements in rdata of SOA record" do
    @result.records.first.rdata.count.should == 7
  end

  it "should fill default_ttl" do
    @result.default_ttl.should be
  end

  it "should parse CNAME records" do
    @result.records[3].type.should == 'CNAME'
  end

  it "should parse A records" do
    rr = @result.records[2]
    rr.type.should == 'A'
    rr.owner.should eql('ns')
    rr.klass.should eql('IN')
    rr.rdata.should eql('192.168.1.200')
  end

  it "should parse TXT records" do
    rr = @result.records[7]
    rr.type.should == 'TXT'
    rr.owner.should eql('human-txt')
    rr.klass.should eql(nil)
    rr.rdata.should eql("'this is text with spases'")
  end

  it "should parse MX records(and mx priority!)" do
    rr = @result.records[4]
    rr.type.should == 'MX'
    rr.owner.should eql('mail')
    rr.klass.should eql('IN')
    rr.rdata.should be_kind_of Array
    rr.rdata.should eql(['40', '192.168.1.33'])
  end
  
  it "should parse records without ttl and class" do
    rr = @result.records[5]
    rr.type.should  eql('CNAME')
    rr.owner.should eql('www')
    rr.klass.should eql(nil)
    rr.rdata.should eql('@')
  end

  it "should parse records after records without ttl and class" do
    rr = @result.records[6]
    rr.owner.should eql('cloud.ru.')
    rr.type.should  eql('A')
    rr.klass.should eql('IN')
    rr.rdata.should eql('192.168.1.1')
  end

  pending "should parse PTR records (12 IN PTR something.com.)" do
  end
end
