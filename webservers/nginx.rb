require 'json'
require 'net/http'
require 'pathname'
require 'tempfile'

class Nginx < Base

  def initialize(config)
    super(config)

    if config['nginx_upstream_name'] == nil
      raise "The nginx driver requires a 'nginx_upstream_name' yaml property"
    end

    #this is ran as sudo
    #config_file = Pathname.new("#{@config['root_path']}/nginx_upstream_#{@config['nginx_upstream_name']}.conf")
    #unless config_file.writable?
    #  raise "#{@config['root_path']}/nginx_upstream_#{@config['nginx_upstream_name']}.conf is not writable"
    #end
  end

  def before_update(current_port)
    ports_to_keep = get_other_ports(current_port)
    new_upstream_content = get_upstream_content(ports_to_keep)
    update_nginx_upstream(new_upstream_content)

    reload_nginx
  end

  def after_update(current_port)
    ports_to_keep = get_other_ports(0)
    new_upstream_content = get_upstream_content(ports_to_keep)
    update_nginx_upstream(new_upstream_content)

    reload_nginx
  end

  def install
    new_upstream_content = get_upstream_content(get_other_ports(0))
    File.write("#{@config['root_path']}/nginx_upstream_#{@config['nginx_upstream_name']}.conf", new_upstream_content)
    `sudo ln -s #{@config['root_path']}/nginx_upstream_#{@config['nginx_upstream_name']}.conf  /etc/nginx/conf.d/#{@config['nginx_upstream_name']}.conf`
  end

  private

  def get_upstream_content(ports)

    upstream_config = "# Do not edit this file. It is controlled by the deployment script\n\n"
    upstream_config += "upstream #{@config['nginx_upstream_name']} {\n"

    ports.each do |port|
      upstream_config += "    server 127.0.0.1:#{port};\n"
    end

    upstream_config += "}\n"

    upstream_config
  end

  def update_nginx_upstream(content)

    file_path = "#{@config['root_path']}/nginx_upstream_#{@config['nginx_upstream_name']}.conf"
    temp_file = Tempfile.new('nginx_upstream')

    temp_file.write(content)
    temp_file.close

    old_stat = File.stat(file_path)

    puts content

    #overwrite the config with the temporary file
    FileUtils.mv(temp_file.path, file_path)
    FileUtils.chmod(old_stat.mode, file_path)

  end

  def reload_nginx
    `sudo service nginx reload`
  end
end
