require 'spec_helper'

describe Bind9mgr::NamedConf do
  before do
    @example_com_db_content = %q{$TTL 86400 ; 1 day
@	IN	SOA	testdomain.com. admin@testdomain.com. (
	1111083002	; serial
	14400		; refresh (4 h)
	3600		; retry (1 h)
	2592000		; expire (4w2d)
	600		; minimum (10 minute)
)
@	IN	NS	ns.example.com.
sub1		IN	A	192.168.1.2
sub2		IN	A	192.168.1.3
alias1  	IN	CNAME	ns
www CNAME @
}

    @test_conf_content = %q{// test file
zone "cloud.ru" {
	type master;
	file "testdomain.com.db";
};

zone "1.168.192.in-addr.arpa" {
	type master;
	file "testdomain.com.db";
};
}

    @test_wrong_conf_content = %q{// test file
zone "cloud.ru" {
	type master;
	file "there_is_no_such_file.com.db";
};

zone "1.168.192.in-addr.arpa" {
	type master;
	file "testdomain.com.db";
};
}

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
    File.stub(:exists?).with("testfile.conf").and_return(true)
    File.stub(:exists?).with("testdomain.com.db").and_return(true)

    File.stub(:read).with(anything()).and_raise(Errno::ENOENT.new("File.read stubbed. You trying to read unexpected file."))
    File.stub(:read).with("testfile.conf").and_return(@test_conf_content)
    File.stub(:read).with("testdomain.com.db").and_return(@test_db_content)

    File.stub(:open).with(anything(),anything()).and_return(true)
    Dir.stub(:mkdir).with(anything()).and_return(true)

    @nc = Bind9mgr::NamedConf.new
    @nc.file = 'testfile.conf'
    @nc.bind_location = ''
    @nc.main_ns = 'ns1.example.com'
    @nc.secondary_ns = 'ns2.example.com'
    @nc.support_email = 'ns1.example.com'
    @nc.main_server_ip = 'ns1.example.com'
    @nc.load_with_zones
  end

  it "should be creatable" do
    expect { Bind9mgr::NamedConf.new }.to_not raise_error
  end

  it "should fill zone parametrs after add" do
    @nc.add_zone "example.com"
    @nc.zones.last.options[:main_ns].should eql("ns1.example.com")
  end

  it "should update undefined zone options on write" do
    Bind9mgr::Zone.any_instance.stub(:write_db_file)
    @nc.zones << Bind9mgr::Zone.new("emptyzone.com")
    @nc.write_zones
    @nc.zones.last.options[:main_ns].should eql("ns1.example.com")
  end

  it "should fail to add_zone(some_string) unless bind_location filled" do
    @nc.bind_location = nil
    expect { @nc.add_zone('example.com') }.to raise_error(ArgumentError)
  end

  it "should fail to add_zone(some_string) unless main NS name filled" do
    @nc.main_ns = nil
    expect { @nc.add_zone('example.com') }.to raise_error(ArgumentError)
  end

  # Behaivor changed. Secondary ns absence causes warning only
  # it "should fail to add_zone(some_string) unless secondary NS name filled" do
  #   @nc.secondary_ns = nil
  #   expect { @nc.add_zone('example.com') }.to raise_error(ArgumentError)
  # end

  it "should fail to add_zone(some_string) unless support email filled" do
    @nc.support_email = nil
    expect { @nc.add_zone('example.com') }.to raise_error(ArgumentError)
  end

  it "should fail to add_zone(some_string) unless main server ip filled" do
    @nc.main_server_ip = nil
    expect { @nc.add_zone('example.com') }.to raise_error(ArgumentError)
  end

  it "should fill @file if argument supplyed on instantiation" do
    nc = Bind9mgr::NamedConf.new('testfile.conf')
    nc.file.should eql 'testfile.conf'
  end

  it "should parse conf file on instantiation if supplyed and file exists" do
    Bind9mgr::NamedConf.any_instance.should_receive(:parse).with(an_instance_of(String)).and_return(nil)
    nc = Bind9mgr::NamedConf.new('testfile.conf')
  end

  it "should have zones after conf file parsing" do
    nc = Bind9mgr::NamedConf.new('testfile.conf')
    nc.zones.count.should == 2
    nc.zones[0].should be_kind_of(Bind9mgr::Zone)
    nc.zones[1].should be_kind_of(Bind9mgr::Zone)
  end

  it "should init zones before load" do
    @nc.zones.count.should == 2 # as specified in "before"
    
    @nc.file = "wrong.file.conf"
    @nc.load
    @nc.zones.should be_empty()
  end

  it "should raise error if you try to assign non-String object to file" do
    expect{ @nc.file = nil }.to raise_error(ArgumentError)
    expect{ @nc.file = 1 }.to raise_error(ArgumentError)
    expect{ @nc.file = '' }.not_to raise_error(ArgumentError)
    expect{ @nc.file = 'qwe' }.not_to raise_error(ArgumentError)
  end


  it "should have an empty array of zones on instantiation without conf file" do
    nc = Bind9mgr::NamedConf.new
    nc.zones.should be_empty()
  end

  it "should load zones data on 'load_with_zones'" do
    @nc.load_with_zones
    @nc.zones.first.records.count.should > 0
  end

  it "should remove old zone when zone with same name added" do
    File.stub(:exists?).with("example.com.db").and_return(true) # lets think that there is no db file for this zone
    File.stub(:read).with("example.com.db").and_return(@example_com_db_content)
    File.stub(:delete).with("example.com.db").and_return(1)

    @nc.add_zone( 'example.com' )
    @nc.zones.last.add_rr( 'cname', nil, nil, 'CNAME', '@' )
    @nc.zones.count.should == 3 # we specified 2 zones in "before"
    @nc.add_zone( 'example.com' )
    @nc.zones.last.records.count.should == 0
    @nc.zones.last.add_default_rrs
    @nc.zones.last.records.count.should == 5 # new zone should have SOA, A, CNAME(www) and 2*NS records
  end

  pending "should automatically generate file name for zone db if not supplied"
  pending "should automatically make dir for zone db files"
  pending "should have methods to edit SOA values"

  it "should have method to load just one zone" do
    @nc.should respond_to :load_one
  end

  it "should load one zone on load_one call" do
    Bind9mgr::Zone.any_instance.should_receive(:load).once
    zone = @nc.load_one 'cloud.ru'
  end

  it "should return loadl zone on load_one call" do
    zone = @nc.load_one 'cloud.ru'
    zone.should be_kind_of Bind9mgr::Zone
    zone.records.count.should > 0
  end

  it "'load!' should raise error if named conf file is missing" do
    @nc.file = "missing.file"
    expect{ @nc.load! }.to raise_error
  end

  it "'load' should not raise error if named conf file is missing" do
    @nc.file = "missing.file"
    expect{ @nc.load }.not_to raise_error
  end

  it "should not fail to load configuration when there is no zone db file" do
    # named conf file with not existing zone db file
    File.stub(:exists?).with("testwrongfile.conf").and_return(true)
    File.stub(:read).with("testwrongfile.conf").and_return(@test_wrong_conf_content) 
    @nc.file = "testwrongfile.conf"

    expect{ @nc.load }.not_to raise_error
    expect{ @nc.load_with_zones }.not_to raise_error
  end
end
