
class Base
  @config = {}

  def initialize(config)
    @config = config
  end

  def before_update(current_port)
    raise NotImplementedError
  end

  def after_update(current_port)
    raise NotImplementedError
  end

  def install
    raise NotImplementedError
  end

  def get_other_ports(exclude)
    servers = @config['servers'].select { |server| server['port'] != exclude }
    servers.map { |server| server['port'] }
  end

end