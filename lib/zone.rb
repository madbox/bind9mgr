module Bind9mgr
  class Zone
    attr_accessor :default_ttl
    attr_accessor :file, :options
    attr_reader :records

    def initialize( zone_name = nil, zone_db_file = nil, options = { } )
      self.origin = zone_name
      @file = zone_db_file
      @options = options

      @default_ttl ||= 86400
      @options[:serial] ||= 109
      @options[:refresh] ||= 3600
      @options[:retry] ||= 3600
      @options[:expiry] ||= 604800
      @options[:default_ttl] ||= 86400
      
      clear_records

      self
    end

    def origin
      @origin
    end

    def origin= zone_origin
      if zone_origin.kind_of?( String ) && zone_origin.length > 0
        @origin = zone_origin.clone
        @origin << '.' unless @origin[-1] == '.'
      else
        @origin = zone_origin 
      end
      @origin
    end

    def name
      @origin.sub(/\.$/, '')
    end

    def name= str
      @origin = str + '.'
    end

    # +rrs_array+ is a array like: [[owner, ttl, klass, type, rdata], ...]
    def self.validete_rrs_uniqueness( rrs_array )
      array = []
      rrs_array.each do |owner, ttl, klass, type, rdata|
        raise( ArgumentError, "owner, type and rdata have to be unique" ) if array.include? [owner,type,rdata]
        array.push [owner,type,rdata]
      end
    end

    def load
      raise ArgumentError, "file not specified" unless @file
      
      # TODO what should we do if there is no db file?
      # raise ArgumentError, "File: #{file} not found." unless File.exists?( @file )
      # just emulate parsing of empty file
      return 0 unless File.exists?( @file )
      
      p = Parser.new
      p.result = self
      begin
        p.parse File.read( @file )
      rescue 
        raise ParserError, "Parser error. File: #{@file.inspect}.\nError: #{$!.to_s}\n#{$!.backtrace.join("\n")}"
      end
    end

    def gen_db_content
      initialized?
      raise ArgumentError, "default_ttl not secified" unless @default_ttl
      
      add_default_rrs

      rrhash = @records.inject({}){|s, v| s[v.type] ||= []; s[v.type] << v; s}

      cont = "; File is under automatic control. Edit with caution.\n"
      cont << ";;; Zone #{@origin} ;;;\n" << "\n"
      cont << "$ORIGIN #{@origin}" << "\n" if @origin
      cont << "$TTL #{@default_ttl}" << "\n" if @default_ttl

      rrhash.keys.each do |rr_type|
        cont << ";;; #{rr_type} ;;;\n"
        cont << rrhash[rr_type].map{ |r| r.gen_rr_string }.join("\n")
        cont << "\n"
      end

      cont
    end
    
    def write_db_file
      raise ArgumentError, "File not specified" if @file.nil? || @file.length < 1
      db_dir = File.dirname( @file )
      raise( Errno::ENOENT, "No such dir: #{db_dir}" ) unless File.exists? db_dir
      File.open( @file, 'w' ){|f| f.write( gen_db_content )}
    end

    def add_default_rrs
      raise ArgumentError, "Main ns not specified" unless @options[:main_ns]
      # TODO main server ip should be renamed to default server ip (or what?)
      raise ArgumentError, "Main server ip not specified" unless @options[:main_server_ip]

      ensure_soa_rr( default_soa )
      ensure_rr( ResourceRecord.new('@', nil, 'IN', 'A', @options[:main_server_ip]) )
      ensure_rr( ResourceRecord.new('@', nil, 'IN', 'NS', @options[:main_ns]) )
      ensure_rr( ResourceRecord.new('@', nil, 'IN', 'NS', @options[:secondary_ns]) ) if @options[:secondary_ns]
      # ensure_rr( ResourceRecord.new('@', nil, 'IN', 'MX', ['90', @options[:mail_server_ip]]) )
      ensure_rr( ResourceRecord.new('www', nil, nil, 'CNAME', '@') )
    end
    
    def add_rr( owner, ttl, klass, type, rdata )
      initialized?
      @records.push ResourceRecord.new(owner, ttl, klass, type, rdata)
    end

    # removes all resourse record with specified owner and type
    def remove_rr( owner, type )
      raise( ArgumentError, "wrong owner" ) if     owner.nil?
      raise( ArgumentError, "wrong type" )  unless ALLOWED_TYPES.include? type

      initialized?

      @records.delete_if { |rr| (rr.owner == owner) && (rr.type == type) }
    end

    def gen_zone_entry
      initialized?

      cont = ''
      cont << %Q|
zone "#{name}" {
  type master;
  file "#{@file}";
  allow-update { none; };
  allow-query { any; };
};
|
    end

    def clear_records
      @records = []
    end

    def ensure_soa_rr record
      raise ArgumentError, "record expected to be Bind9mgr::ResourceRecord" unless record.kind_of? ResourceRecord
      cnt = @records.select{ |r| r.type == 'SOA' }.count
      raise RuntimeError, "Multiple SOA detected. zone:#{@origin}" if cnt > 1
      return false if cnt == 1
      @records.unshift record
      true
    end

    def ensure_rr record
      raise ArgumentError, "record expected to be Bind9mgr::ResourceRecord" unless record.kind_of? ResourceRecord
      max_rr_cnt = (record.type == 'NS' ? 2 : 1)
      cnt = @records.select{ |rr| (rr.owner == record.owner) && (rr.type == record.type) }.count
      raise RuntimeError, "Multiple rr with same owner+type detected. zone:#{@origin}" if cnt > max_rr_cnt
      return false if cnt == max_rr_cnt
      @records.push record
      true
    end

    def self.domain_name_syntax_valid( string )
      ! string.match(/^([\w\d\-]{2,}\.)+(\w{2,})\.?$/).nil?
    end

    def valid?
      return false if @records.size < 1
      return false unless Bind9mgr::Zone.domain_name_syntax_valid( self.origin )
      @records.select{ |z| !z.valid? }.size == 0
    end

    private

    def default_soa
      initialized?
      raise ArgumentError, "Main ns not secified" unless @options[:main_ns]
      raise ArgumentError, "Support email not secified" unless @options[:support_email]

      ResourceRecord.new( '@', @options[:default_ttl], 'IN', 'SOA', 
                          [ @origin,
                            @options[:support_email],
                            @options[:serial],
                            @options[:refresh],
                            @options[:retry],
                            @options[:expiry],
                            @options[:default_ttl]
                          ] )
    end

    def initialized?
      raise( ArgumentError, "zone not initialized" ) if  @origin.nil?
    end
    
  end
end
