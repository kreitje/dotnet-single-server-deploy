require 'net/http'
require 'time'
require './webservers/base'
require './webservers/caddy'
require './webservers/nginx'

class Deploy

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
    puts "Starting deployment"

    app_name = get_app_name
    release_name = Time.now.strftime("%Y%m%d%H%M")
    release_directory = "#{@config['root_path']}/releases/#{release_name}"

    # create new releases directory
    puts "Release directory = #{release_directory}"
    unless @dry_run
      `mkdir -p #{release_directory}`
    end

    puts "Extract zip file to release directory"
    # extract zipfile to releases directory
    unless @dry_run
      `exec unzip #{@config['update_zip_absolute_path']} -d #{release_directory}`
    end

    @config['servers'].each_with_index do |app, index|

      #update webserver removing this server
      puts "Updating server running on #{app['port']}"
      unless @dry_run
        @webserver.before_update(app['port'])
      end

      sleep(2)

      puts "Stop service"
      unless @dry_run
        `sudo systemctl stop kestrel-#{app_name}_#{app['port']}.service`
      end

      puts "Copying files to app directory"
      unless @dry_run
        `cp -Rf #{release_directory}/* #{app['path']}`
      end

      if @config['shared_files'].length > 0
        puts "Copying shared files"
        @config['shared_files'].each do |file|
          source = "#{@config['root_path']}/shared/#{file}"
          destination = "#{app['path']}/#{file}"

          puts " ... copy #{source} to #{destination}"
          unless @dry_run
            `cp #{source} #{destination}`
          end
        end
      end

      puts "Start service"
      unless @dry_run
        `sudo systemctl start kestrel-#{app_name}_#{app['port']}.service`
      end

      healthcheck_passed = false
      healthcheck_counter = 0

      if @dry_run
        healthcheck_passed = true
      end

      print "Checking health check "
      until healthcheck_passed
        healthcheck_passed = verify_healthcheck?(app['port'])
        healthcheck_counter += 1

        if healthcheck_counter > 10
          raise "Could not verify health check on #{app['port']}"
        end

        print "."
        unless healthcheck_passed
          sleep(2)
        end

      end

      puts ""
      puts " ... done updating server running on #{app['port']}"
      puts " ... putting #{app['port']} back into the upstream"
      unless @dry_run
        @webserver.after_update(app['port'])
      end

    end

    puts "Done deploying."

  end

  private

  def verify_healthcheck?(port)
    begin
      uri = URI.parse("http://127.0.0.1:#{port}#{@config['healthcheck']}")
      request = Net::HTTP::Get.new(uri)
      request.content_type = "application/json"

      response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(request)
      end

      #puts response.response.body
      response.code == '200'
    rescue
      false
    end
  end

  def get_app_name
    @config['root_path'].split('/').last
  end

end