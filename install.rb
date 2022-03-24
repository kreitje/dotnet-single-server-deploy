
class Install

  @config = {}
  @dry_run = true
  @webserver = nil

  def initialize(config, dry_run = true)
    @config = config
    @dry_run = dry_run

    case config['webserver']
    when "caddy"
      @webserver = Caddy.new(config)
    when "nginx"
      @webserver = Nginx.new(config)
    else
      raise "Invalid webserver type"
    end
  end

  def execute
    puts "Execute the install"

    puts "Creating root path and shared directory"

    unless @dry_run
      `mkdir -p #{@config['root_path']}/shared`
      `mkdir -p #{@config['root_path']}/releases`
    end

    app_name = get_app_name

    @config['servers'].each_with_index do |app, index|
      puts "Creating #{app['path']} for port #{app['port']} directory"
      unless @dry_run
        `mkdir -p #{app['path']}`
      end

      write_service_file(app['path'], app['port'])
      unless @dry_run
        `systemctl enable kestrel-#{app_name}_#{app['port']}.service`
      end
    end

    puts "Doing webserver install"
    @webserver.install

    `chown -R www-data:www-data #{@config['root_path']}`
    `chmod -R 775 #{@config['root_path']}`
  end

  private

  def get_app_name
    @config['root_path'].split('/').last
  end

  def write_service_file(path, port)
    app_name = get_app_name
    contents = service_file_contents

    contents.gsub!("NAME_REPLACE", app_name)
    contents.gsub!("PORT_REPLACE", port.to_s)
    contents.gsub!("PATH_REPLACE", path)
    contents.gsub!("DLL_REPLACE", @config['app_dll'])

    file_path = "/etc/systemd/system/kestrel-#{app_name}_#{port}.service"
    puts "Writing content to #{file_path}"
    if @dry_run
      puts contents
    else
      File.write(file_path, contents)
    end
  end


  def service_file_contents
    return <<SERVICE_FILE
[Unit]
Description=NAME_REPLACE PORT_REPLACE Service

[Service]
WorkingDirectory=PATH_REPLACE
ExecStart=/usr/bin/dotnet PATH_REPLACE/DLL_REPLACE
Restart=always
# Restart service after 10 seconds if the dotnet service crashes:
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=NAME_REPLACE-PORT_REPLACE
User=www-data
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false
Environment=ASPNETCORE_URLS=http://0.0.0.0:PORT_REPLACE

[Install]
WantedBy=multi-user.target
SERVICE_FILE
  end

end
