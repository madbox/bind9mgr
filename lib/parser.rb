module Bind9mgr
  TYPES = %w{A CNAME TXT PTR NS SRV} # SOA, MX - are different
  class Parser

    attr_reader :state
    attr_accessor :result # we can set appropriate Zone instance here

    def initialize
      @state = :start
      @result = Zone.new

      @STATE_RULES = 
        [ [:start, :origin, Proc.new{ |t| t == '$ORIGIN' }],
          [:origin, :start, Proc.new{ |t| set_origin t }],
          [:start, :ttl,    Proc.new{ |t| t == '$TTL' }],
          [:ttl, :start,    Proc.new{ |t| set_ttl t }],
          [:start, :type,   Proc.new{ |t| TYPES.include?(t) ? add_rr(nil, nil, nil, t, nil) : false }],
          [:start, :klass,  Proc.new{ |t| KLASSES.include?(t) ? add_rr(nil, nil, t, nil, nil) : false }],
          [:start, :rttl,   Proc.new{ |t| t.match(/^\d+$/) ? add_rr(nil, t, nil, nil, nil) : false }],
          [:start, :owner,  Proc.new{ |t| add_rr(t, nil, nil, nil, nil) }],
          [:owner, :rttl,   Proc.new{ |t| t.match(/^\d+$/) ? update_last_rr(nil, t, nil, nil, nil) : false }],
          [:owner, :klass,  Proc.new{ |t| KLASSES.include?(t) ? update_last_rr(nil, nil, t, nil, nil) : false }],
          [:owner, :type,   Proc.new{ |t| TYPES.include?(t) ? update_last_rr(nil, nil, nil, t, nil) : false }],
          [:rttl,  :klass,  Proc.new{ |t| KLASSES.include?(t) ? update_last_rr(nil, nil, t, nil, nil) : false }],
          [:klass, :type,   Proc.new{ |t| TYPES.include?(t) ? update_last_rr(nil, nil, nil, t, nil) : false }],
          [:type, :start,   Proc.new{ |t| update_last_rr(nil, nil, nil, nil, t)  }],
          [:klass, :soa,    Proc.new{ |t| t == 'SOA' ? update_last_rr(nil, nil, nil, t, nil) : false }],
          [:soa, :start,    Proc.new{ |t| rdata = [t] + @tokens.shift(7)
             raise RuntimeError, "Zone parsing error: parentices expected in SOA record.\n#{@content}" if (rdata[2] != '(') && (@tokens.first != ')')
             rdata.delete_at(2)
             @result.options[:support_email] = rdata[1]
             @result.options[:serial] = rdata[2]
             @result.options[:refresh] = rdata[3]
             @result.options[:retry] = rdata[4]
             @result.options[:expiry] = rdata[5]
             @result.options[:default_ttl] = rdata[6]
             update_last_rr(nil, nil, nil, nil, rdata)
             @tokens.shift
           }],
          [:klass, :mx,     Proc.new{ |t| t == 'MX' ? update_last_rr(nil, nil, nil, t, nil) : false }],
          [:mx, :start,     Proc.new{ |t| update_last_rr(nil, nil, nil, nil, [t] + [@tokens.shift]) }]
        ]
    end

    def parse str
      @content = str # for debugging
      @tokens = tokenize( str )
      
      cntr = 0
      while @tokens.size > 0
        token = @tokens.shift
        # puts "state: #{@state}, token: #{token}"
        possible_edges = @STATE_RULES.select{|arr|arr[0] == @state }
        raise "no possible_edges. cur_state: #{@state}" if possible_edges.count < 1

        flag = false
        while ( possible_edges.count > 0 ) && flag == false
          current_edge = possible_edges.shift
          flag = current_edge[2].call(token)
          
          # ( puts " succ: #{@state} -> #{current_edge[1]}"; @state = current_edge[1] ) if flag
          # ( puts " fail: #{@state} -> #{current_edge[1]}" ) unless flag
          @state = current_edge[1] if flag
        end

        raise "no successful rules found. cur_state: #{@state}, token: #{token}" unless flag
        cntr += 1
      end

      get_options

      cntr # returning performed rules count. just for fun
    end
 
    private

    def tokenize str
      str.gsub(/;.*$/, '').split(/\s/).select{|s|s.length > 0}
    end

    def get_options
      # main server ip
      main_a_rr = @result.records.find{ |r|(r.owner == '@' || r.owner == @result.origin || r.owner.nil?) && r.type == 'A' }
      unless main_a_rr
        puts "WARNING: main A rr not found. Can't get main server ip" 
      else
        @result.options[:main_server_ip] = main_a_rr.rdata
      end
      # name servers
      ns_rrs = @result.records.select{ |r| (r.owner == '@' || r.owner == @result.origin || r.owner.nil?) && r.type == 'NS' }
      if ns_rrs.count < 1
        puts "WARNING: NS rrs not found. Can't NS servers" 
      else
        @result.options[:main_ns] = ns_rrs[0].rdata
        @result.options[:secondary_ns] = ns_rrs[1].rdata if ns_rrs.count > 1
      end
    end

    def set_origin val
      @result.origin = val
    end

    def set_ttl val
      @result.default_ttl = val
    end

    def add_rr owner, ttl, klass, type, rdata
      @result.records ||= []
      @result.records.push ResourceRecord.new( owner, ttl, klass, type, rdata )
    end
    
    def update_last_rr owner, ttl, klass, type, rdata 
      @result.records.last.owner  = owner  if owner
      @result.records.last.ttl    = ttl    if ttl
      @result.records.last.klass  = klass  if klass
      @result.records.last.type   = type   if type
      @result.records.last.rdata  = rdata  if rdata
      return true
    end
  end
end
