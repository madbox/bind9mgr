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

  it "shoult have a list of allowed rr types" do
    Bind9mgr::ALLOWED_TYPES.should be_kind_of(Array)
    Bind9mgr::ALLOWED_TYPES.count.should > 0
  end
end
