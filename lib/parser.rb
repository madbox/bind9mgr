module Bind9mgr
  # this TYPES will be parsed with simplified state_rules chain
  TYPES = %w{A CNAME PTR NS} # SOA, MX, TXT, SRV - are different
  class Parser

    attr_reader :state
    attr_accessor :result # we can set appropriate Zone instance here

    def initialize
      @state = :start
      @result = Zone.new

      @SHARED_RULES = {
        :txt => Proc.new{ |t| t == 'TXT' ? update_last_rr(nil, nil, nil, t, nil) : false },
        :mx  => Proc.new{ |t| t == 'MX'  ? update_last_rr(nil, nil, nil, t, nil) : false },
        :srv => Proc.new{ |t| t == 'SRV' ? update_last_rr(nil, nil, nil, t, nil) : false }
      }

      @STATE_RULES = 
        # [current_state, target_state, proc to perform(token will be passe in)
        [ [:start, :origin, Proc.new{ |t| t == '$ORIGIN' }],
          [:start, :ttl,    Proc.new{ |t| t == '$TTL' }],
          [:origin, :last_token_in_a_row, Proc.new{ |t| set_origin t }],
          [:ttl, :last_token_in_a_row,    Proc.new{ |t| set_ttl t }],
          [:last_token_in_a_row, :start, Proc.new{ |t| t == "\n" ? true : false }],
          [:owner, :rttl,   Proc.new{ |t| t.match(/^\d+$/) ? update_last_rr(nil, t, nil, nil, nil) : false }],
          [:owner, :klass,  Proc.new{ |t| KLASSES.include?(t) ? update_last_rr(nil, nil, t, nil, nil) : false }],
          [:owner, :type,   Proc.new{ |t| TYPES.include?(t) ? update_last_rr(nil, nil, nil, t, nil) : false }],
          [:owner, :mx,     @SHARED_RULES[:mx]],
          [:owner, :srv,    @SHARED_RULES[:srv]],
          [:owner, :txt,    @SHARED_RULES[:txt]],
          [:rttl,  :klass,  Proc.new{ |t| KLASSES.include?(t) ? update_last_rr(nil, nil, t, nil, nil) : false }],
          [:rttl,  :txt,    @SHARED_RULES[:txt]],
          [:rttl,  :srv,    @SHARED_RULES[:srv]],
          [:klass, :mx,     @SHARED_RULES[:mx]],
          [:klass, :txt,    @SHARED_RULES[:txt]],
          [:klass, :srv,    @SHARED_RULES[:srv]],
          [:klass, :type,   Proc.new{ |t| TYPES.include?(t) ? update_last_rr(nil, nil, nil, t, nil) : false }],
          [:klass, :soa,    Proc.new{ |t| t == 'SOA' ? update_last_rr(nil, nil, nil, t, nil) : false }],
          [:type,  :last_token_in_a_row,   Proc.new{ |t| update_last_rr(nil, nil, nil, nil, t)  }],
          [:start, :type,   Proc.new{ |t| TYPES.include?(t) ? add_rr(nil, nil, nil, t, nil) : false }],
          [:start, :klass,  Proc.new{ |t| KLASSES.include?(t) ? add_rr(nil, nil, t, nil, nil) : false }],
          [:start, :rttl,   Proc.new{ |t| t.match(/^\d+$/) ? add_rr(nil, t, nil, nil, nil) : false }],
          [:start,  :srv,    @SHARED_RULES[:srv]],
          [:start,  :txt,    @SHARED_RULES[:txt]],
          [:start, :owner,  Proc.new{ |t| add_rr(t, nil, nil, nil, nil) }],
          [:soa, :last_token_in_a_row,    Proc.new{ |t|
             rdata = [t] + @tokens.shift(@tokens.index(')'))
             rdata.select!{|tt| tt != "\n" }
             raise ParserError, "Zone parsing error: parentices expected in SOA record.\n#{@content}" if (rdata[2] != '(') || (@tokens.first != ')')
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
          [:mx, :last_token_in_a_row,     Proc.new{ |t| update_last_rr(nil, nil, nil, nil, [t] + [@tokens.shift]) }], 
          [:srv, :last_token_in_a_row,     Proc.new{ |t| update_last_rr(nil, nil, nil, nil, [t] + [@tokens.shift(3)]) }], 
          [:txt, :last_token_in_a_row,     Proc.new{ |t| update_last_rr(nil, nil, nil, nil, ([t] + [@tokens.shift(@tokens.index("\n"))]).join(" ")) }] # '\t' symbol is lost here! may be a BUG
        ]
    end

    def parse str
      @content = str # for debugging
      @tokens = tokenize( str )
      
#      puts @tokens.inspect

      cntr = 0
      while @tokens.size > 0
        token = @tokens.shift
        # puts "state: #{@state}, token: #{token}"
        possible_edges = @STATE_RULES.select{|arr|arr[0] == @state }
        raise( ParserError, "no possible_edges. cur_state: #{@state}" ) if possible_edges.count < 1

        flag = false
        while ( possible_edges.count > 0 ) && flag == false
          current_edge = possible_edges.shift
          flag = current_edge[2].call(token)
          
          # ( puts " succ: #{@state} -> #{current_edge[1]}"; @state = current_edge[1] ) if flag
          # ( puts " fail: #{@state} -> #{current_edge[1]}" ) unless flag
          @state = current_edge[1] if flag
        end

        raise( ParserError, "no successful rules found. cur_state: #{@state}, token: #{token}, next tokens: #{@tokens.inspect}" ) unless flag
        cntr += 1
      end

      get_options

      cntr # returning performed rules count. just for fun
    end
 
    private

    def tokenize str
      str.gsub!(/;.*$/, '')
      str.squeeze!("\n\t\r")
      dirty_tokens = str.split(/[ \t\r]/)
      
      tokens = []
      dirty_tokens.each do |t|

        if t.index("\n")
#          puts "n found: #{t.inspect}"
          while t.index("\n") do
            i = t.index("\n")-1
#            puts "slice: #{i}, #{t.slice(0..(i >= 0 ? i : 0))}"
            tokens << t.slice!(0..i) if i >= 0
#            puts "after slice: #{t.inspect}"
            tokens << "\n"            
#            puts "cut:" + t.slice(0..0).inspect
            t.slice!(0..0)
          end
#          puts "add after cut:#{t.inspect}"
          tokens << t
        else
#          puts "just add:#{t}"
          tokens << t
        end

      end

      tokens.select!{|s|s.length > 0}

      if tokens[0] == "\n"
        tokens.shift
      end

      tokens
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
