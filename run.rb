#!/usr/bin/env ruby
require 'optparse'
require 'yaml'
require "./install.rb"
require "./deploy.rb"

options = {
  :config => "./config.yml",
  :dry_run => true
}
OptionParser.new do |opts|
  opts.banner = "Usage: run.rb [options]"

  opts.on("-c", "--config=PATH_TO_CONFIG", "Path to custom configuration file") do |c|
    options[:config] = c
  end

  opts.on("-d", "--dry-run=TRUE", "Should we dry run") do |d|
    options[:dry_run] = d.upcase != "FALSE"
  end
end.parse!

puts "Config file is #{options[:config]}"

config = YAML.load_file(options[:config])
if ARGV.length == 0
  puts "Please specify either 'deploy' or 'install'"
  exit(1)
end

case ARGV[0]
when "deploy"
  deployer = Deploy.new(config, options[:dry_run])
  deployer.execute
when "install"
  installer = Install.new(config, options[:dry_run])
  installer.execute
else
  puts "Enter deploy or install"
  exit(1)
end
