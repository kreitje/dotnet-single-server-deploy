require 'yaml'
require "./install.rb"
require "./deploy.rb"

config = YAML.load_file('config.yml')
dry_run = true

if ARGV.length == 0
  puts "Please specify either 'deploy' or 'install'"
  exit(1)
end

if ARGV.length >= 2 && ARGV[1] == "run"
  dry_run = false
end

case ARGV[0]
when "deploy"
  deployer = Deploy.new(config, dry_run)
  deployer.execute
when "install"
  installer = Install.new(config, dry_run)
  installer.execute
else
  puts "Enter deploy or install"
  exit(1)
end
