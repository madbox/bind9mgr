require 'spec_helper'

describe Bind9mgr::ResourceRecord do
  before do
    @rr = Bind9mgr::ResourceRecord.new
    @a_string = %q{example.com. IN A 192.168.1.1}
    @cname_string = %q{cname IN CNAME @
}
    @soa_string = %q{@	IN	SOA	cloud.ru. root.cloud.ru. (
 	2011083002	; serial
	14400		; refresh (4 h)
	3600		; retry (1 h)
	2592000		; expire (4w2d)
	600		; minimum (10 minute)
)
}
    @mx_string = %q{example.com.        IN      MX  10   mail.example.com.}
  end

  it "should be instanceable" do
    expect { Bind9mgr::ResourceRecord.new }.to_not raise_error
  end

  it "should have methods to fill parametrs" do
    @rr.should respond_to( :owner, :ttl, :type, :klass, :rdata )
  end

  it "should have method to generate rr string" do
    @rr.should respond_to( :gen_rr_string )
  end

  it "should raise error when wrong record exists on gen_rr_string" do
    expect { @rr.gen_rr_string }.to raise_error
  end

  it "should fill errors array with something on validation" do
    @rr.should_not be_valid
    @rr.errors.size.should > 0
    puts @rr.errors
  end

  it "should not raise error when valid record exists on gen_rr_string" do
    @rr.owner = '@'
    @rr.type = 'A'
    @rr.rdata = '123.123.123.123'
    
    expect { @rr.gen_rr_string }.not_to raise_error
  end

  describe "A records validation" do
    subject { Bind9mgr::ResourceRecord }
    
    it( "with normal data" ) { subject.new( 'sub', nil, 'IN', 'A', '192.168.1.1' ).should be_valid }
    it( "without class"    ) { subject.new( 'sub', nil, nil, 'A', '192.168.1.1' ).should be_valid }
    it( "with blank owner" ) { subject.new( '', nil, 'IN', 'A', '192.168.1.1' ).should be_valid }
    it( "with nil owner"   ) { subject.new( nil, nil, 'IN', 'A', '192.168.1.1' ).should be_valid }
    
    it( "with '1' in all fields"     ) { subject.new( '1', '1', '1', 'A', '1' ).should_not be_valid }
    it( "with digit in owner"        ) { subject.new( '1', nil, 'IN', 'A', '192.168.1.1' ).should_not be_valid }
    it( "with double digit in owner" ) { subject.new( '11', nil, 'IN', 'A', '192.168.1.1' ).should_not be_valid }
    it( "with blank rdata"           ) { subject.new( 'sub', nil, 'IN', 'A', '' ).should_not be_valid }
    it( "with nil rdata"             ) { subject.new( 'sub', nil, 'IN', 'A', nil ).should_not be_valid }
    it( "with digit in rdata"        ) { subject.new( '1', nil, 'IN', 'A', '1' ).should_not be_valid }
    it( "with char in rdata"         ) { subject.new( '1', nil, 'IN', 'A', 's' ).should_not be_valid }
    it( "with punctuation in rdata"  ) { subject.new( '1', nil, 'IN', 'A', ',;;;' ).should_not be_valid }
    it( "with wrong class"           ) { subject.new( 'sub', nil, 'IN222', 'A', '192.168.1.1' ).should_not be_valid }
  end

  describe "SOA records validation" do
    subject { Bind9mgr::ResourceRecord }

    it( "with normal data" ) { subject.new( '@', nil, 'IN', 'SOA', ['qwe.com.', 'support@qwe.com', '123', '123', '123', '123', '123'] ).should be_valid }
    it( "with wrong origin in rdata" ) { subject.new( '@', nil, 'IN', 'SOA', ['qwe', 'qwe', '123', '123', '123', '123', '123'] ).should_not be_valid }
    it( "with wrong rdata size" ) { subject.new( '@', nil, 'IN', 'SOA', ['123', '123', '123'] ).should_not be_valid }
    it( "with wrong rdata kind" ) { subject.new( '@', nil, 'IN', 'SOA', 'qwe' ).should_not be_valid }

  end

  it "shoult have a list of allowed rr types" do
    Bind9mgr::ALLOWED_TYPES.should be_kind_of(Array)
    Bind9mgr::ALLOWED_TYPES.count.should > 0
  end
end
