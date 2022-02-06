require 'net/http'
require 'json'

class Caddy < Base

  def initialize(config)
    super(config)

    if config['caddy_upstream_key'] == nil
      raise "The caddy driver requires a 'caddy_upstream_key' yaml property"
    end
  end

  def before_update(current_port)
    ports_to_keep = get_other_ports(current_port)
    json_to_patch = get_upstream_json(ports_to_keep)
    update_caddy_upstreams(json_to_patch)
  end

  def after_update(current_port)
    ports_to_keep = get_other_ports(0)
    json_to_patch = get_upstream_json(ports_to_keep)
    update_caddy_upstreams(json_to_patch)
  end

  private

  def get_upstream_json(ports)
    upstream_config = []

    ports.each do |port|
      upstream_config.push({
        dial: "127.0.0.1:#{port}"
      })
    end

    upstream_config.to_json
  end

  def update_caddy_upstreams(json)
    uri = URI.parse("http://127.0.0.1:2019/id/#{@config['caddy_upstream_key']}/upstreams")
    request = Net::HTTP::Patch.new(uri)
    request.content_type = "application/json"
    request.body = json

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    if response.code != '200'
      raise "Invalid status code when updating Caddy upstream #{response.code}"
    end
  end

end