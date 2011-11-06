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
  
  it "should return self on instantiation" do
    Bind9mgr::Zone.new.should be_kind_of( Bind9mgr::Zone )
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

  describe "records creation & validation" do
    subject do
      Bind9mgr::Zone.new( 'example.com', 'example.com.db',
                          { :main_ns => '192.168.1.1',
                            :secondary_ns => '192.168.1.2',
                            :main_server_ip => '192.168.1.3',
                            :support_email => 'qwe@qwe.ru'
                          } )
    end

    it "should has method to check domain name syntax" do
      Bind9mgr::Zone.domain_name_syntax_valid( "qw.ru" ).should be_true
      Bind9mgr::Zone.domain_name_syntax_valid( "rew.qw.ru" ).should be_true
      Bind9mgr::Zone.domain_name_syntax_valid( "werwer-qw.ru" ).should be_true
      Bind9mgr::Zone.domain_name_syntax_valid( "q.ru" ).should be_false
      Bind9mgr::Zone.domain_name_syntax_valid( "11qweqwe.ru" ).should be_true
      Bind9mgr::Zone.domain_name_syntax_valid( "q.r" ).should be_false
      Bind9mgr::Zone.domain_name_syntax_valid( "q.11" ).should be_false
    end

    it "should validate domain name" do
      subject.origin = 'qwe qwe qwe.com'
      subject.add_default_rrs
      subject.should_not be_valid
    end

    it "should add default rrs before generate db content" do
      subject.gen_db_content
      subject.records.size.should > 0
    end
    
    it "should add dot to zone name on creation unless there is no one" do
      subject.origin.should eql('example.com.')
      subject.name.should eql('example.com')
    end
    
    it "should not be valid without records" do
      subject.should_not be_valid
    end
    
    it "should pass when there are default records and some valid ones" do
      subject.add_default_rrs
      subject.add_rr( 'qwe', nil, nil, 'CNAME', '@' )
      subject.should be_valid
    end
    
    it "should not be valid with wrong records" do
      subject.add_default_rrs
      subject.add_rr( 'qwe', nil, nil, 'CNAME', '' )
      subject.should_not be_valid
    end
  end

  pending "should raise error when undefined rr target added" do
    # examples
    # 1:
    # @ NS ns.example.com # here is no dot at the end of line -> error!
    #
    # 2:
    # ns.example.com CNAME @
    # @ NS ns.example.com # here is no dot at the end of line but this is not error: subdomain really defined
  end

end
