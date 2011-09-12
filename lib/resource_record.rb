module Bind9mgr
  class ResourceRecord
    attr_accessor :owner, :ttl, :klass, :type, :rdata

    def initialize owner = nil, ttl = nil, klass = nil, type = nil, rdata = nil
      @owner = owner
      @ttl = ttl
      @klass = klass
      @type = type
      @rdata = rdata
    end

    def gen_rr_string
      raise ArgumentError, "RR Type not specified" unless @type
      raise ArgumentError, "RR Rdata not specified" unless @rdata

      raise( ArgumentError, "wrong owner: #{owner.inspect}" ) if owner == 'localhost'
      raise( ArgumentError, "wrong class: #{klass.inspect}" ) if !klass.nil? && !KLASSES.include?( klass ) 
      raise( ArgumentError, "wrong type: #{type.inspect}" )  unless ALLOWED_TYPES.include?( type )

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
