module Bind9mgr
  # You can specify bind_location. If you do so then .add_zone method
  # will generate zones with right filenames.
  # If .file
  class NamedConf
    #    BIND_PATH = '/etc/bind'
    #    BIND_DB_PATH = BIND_PATH + '/master'

    attr_accessor :file, :main_ns, :secondary_ns, :support_email, :main_server_ip, :bind_location
    attr_reader :zones

    def initialize( file = '' )
      @file = file
      @bind_location = File.dirname(file) if file.length > 1
      load
    end

    def file= str
      raise ArgumentError, "String expected" unless str.kind_of? String
      @file = str
    end

    # Tries to load data from named conf. Raises exception if file missing.
    def load!
      init_zones
      parse File.read( @file ) if file.length > 0
    end

    # Tries to load data from named conf. Do nothing if file missing.
    def load
      init_zones
      parse File.read( @file ) if File.exists?(@file)
    end

    # Load just one zone and return it
    def load_one( zone_name )
      raise ArgumentError, "Zone name expected to be a string" unless zone_name.kind_of? String
      load
      if zone = zones.find{ |z| z.name == zone_name }
        zone.load
      end
      zone
    end

    def load_with_zones
      load
      zones.each{ |z| z.load}
    end


    def parse content
      content.scan(/(zone "(.*?)" \{.*?file\s+"(.*?)".*?\};\n)/m) do |zcontent, zone, file|
        @zones.push Zone.new( zone, file, 
                              :main_ns => @main_ns,
                              :secondary_ns => @secondary_ns,
                              :support_email => @support_email,
                              :main_server_ip => @main_server_ip )
      end
      @zones
    end

    def gen_conf_content
      cont = '# File is under automatic control. Edit with caution.' 
      if @zones.size > 0
        @zones.uniq.each do |zone|
          cont << zone.gen_zone_entry << "\n"
        end
      end
      cont
    end

    def write_conf_file
      raise ArgumentError, "Conf file not specified" unless @file.kind_of? String
      File.open( @file, 'w' ){|f| f.write( gen_conf_content )}
    end

    def write_zones
      @zones.uniq.each do |z| 
        z.file ||= gen_zone_file_name( z.origin );
        zones_subdir = File.dirname( z.file )
        Dir.mkdir( zones_subdir ) unless File.exists?( zones_subdir )

        # OPTIMIZE this
        z.options[:main_ns]        ||= @main_ns
        z.options[:secondary_ns]   ||= @secondary_ns
        z.options[:support_email]  ||= @support_email
        z.options[:main_server_ip] ||= @main_server_ip

        z.write_db_file
      end if @zones.size > 0
    end

    def write_all
      write_conf_file
      write_zones
    end

    def add_zone( zone_or_name, file_name = nil )
      if zone_or_name.kind_of?( Zone )
        raise ArgumentError, "file_name should be nil if instance of Zone supplied" unless file_name.nil?
        zone = zone_or_name
      elsif zone_or_name.kind_of?( String ) && ( zone_or_name.length > 4 ) # at last 'a.a.'
        raise ArgumentError, "Main ns not secified" unless @main_ns
        # raise ArgumentError, "Secondary ns not secified" unless @secondary_ns
        raise ArgumentError, "Support email not secified" unless @support_email
        raise ArgumentError, "Main server ip not secified" unless @main_server_ip
        
        zone = Zone.new( zone_or_name,
                         file_name || gen_zone_file_name(zone_or_name), 
                         :main_ns => @main_ns,
                         :secondary_ns => @secondary_ns,
                         :support_email => @support_email,
                         :main_server_ip => @main_server_ip,
                         :mail_server_ip => @mail_server_ip)
      else
        raise( RuntimeError, "BindZone or String instance expected, but #{zone_or_name.inspect} got")
      end

      del_zone! zone.origin
      @zones.push zone
      zone
    end
    
    def find( origin_or_name )
      @zones.select{ |z| z.origin == origin_or_name || z.name == origin_or_name }
    end

    # We should remove zone enties and delete db file immidiately.
    def del_zone!( origin_or_name )
      founded = @zones.select{ |z| z.origin == origin_or_name || z.name == origin_or_name }
      founded.each do |z| 
        z.load
        File.delete( z.file ) if File.exists? z.file
      end
      # TODO refactor!
      if founded.count > 0
        @zones.delete_if{ |z| z.origin == origin_or_name || z.name == origin_or_name }
      end
      
      # TODO unsafe code: other zone entries can be updated!
      write_conf_file
    end

    private

    def gen_zone_file_name( zone_name )
      raise ArgumentError, "Bind location not specified" unless bind_location.kind_of?( String )
      ext_zone_name = zone_name + '.db'

      return ext_zone_name if bind_location.length < 1
      return File.join( bind_location, ZONES_BIND_SUBDIR, ext_zone_name )
    end

    def init_zones
      @zones = []
    end
  end
end
