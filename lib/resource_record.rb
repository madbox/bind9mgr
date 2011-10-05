module Bind9mgr
  class ResourceRecord
    attr_accessor :owner, :ttl, :klass, :type, :rdata
    attr_reader :errors

    def initialize owner = nil, ttl = nil, klass = nil, type = nil, rdata = nil
      @owner = owner
      @ttl = ttl
      @klass = klass
      @type = type
      @rdata = rdata
    end

    # Validations
    ##

    def valid?
      @errors = []
      (@errors << "Base type_and_rdata_shouldnt_be_blank"; return false)   unless @type && @rdata
      (@errors << "Owner invalid")                                         if     @owner && ( !@owner.kind_of?(String) || (@owner.length < 1) || (@owner.match(/^\d+$/)) || (@owner == 'localhost') )
      (@errors << "Class invalid")                                         if     !klass.nil? && !KLASSES.include?( klass ) 
      (@errors << "Type not_supported")                                    unless ALLOWED_TYPES.include?( type )

      validate_method_name = "validate_#{@type.downcase}"
      
      self.class.send validate_method_name if self.class.respond_to?(validate_method_name)

      return @errors.size == 0
    end

    def validate_a
      @errors << "Base a record validation is under construction"
    end

    def validate_cname 
      @errors << "Base cname record validation is under construction"
    end

    def validate_mx
      @errors << "Base mx record validation is under construction"
    end

    ##
    # Validations

    def gen_rr_string
      raise MalformedResourceRecord, "Owner:'#{@owner}', ttl:'#{@ttl}', class:'#{klass}', type:'#{type}', rdata:'#{rdata}'" unless self.valid?

      if @type == 'SOA'
        cont = ''
        cont << "#{@owner}\t#{@ttl}\t#{@klass}\t#{@type}\t#{rdata[0]} #{rdata[1]} (\n"
        cont << "\t#{Time.now.to_i} ; serial\n"
        cont << "\t#{rdata[3]} ; refresh\n"
        cont << "\t#{rdata[4]} ; retry\n"
        cont << "\t#{rdata[5]} ; expire\n"
        cont << "\t#{rdata[6]} ; minimum\n"
        cont << ")\n"
      else
        "#{@owner}\t#{@ttl}\t#{@klass}\t#{@type}\t#{[@rdata].flatten.join(' ')}\n"
      end
    end
  end
end
