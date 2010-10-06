#!/usr/bin/env ruby
require 'rubygems'
require 'xmlsimple'
require 'mechanize'

$project_name = ARGV[0]
$hostname = ARGV[1]
$username = ARGV[2]
$password = ARGV[3]

# NB: currently throws errors to cron if build server is down
# NB: keeps track of build number on disk, so if build server is reset this script gets screwy

DATA_FILE = File.join(File.dirname(__FILE__), "build_poller.#{$project_name}.data")

class Poller
  CURRENT_BUILD_URL = "http://#{$hostname}/j_acegi_security_check?j_username=#{$username}&j_password=#{$password}&from=%2Fjob%2F#{$project_name}%2Fapi%2Fxml%3Fdepth%3D1%26xpath%3D%2F%2Fbuild%5Bresult%3D%2527SUCCESS%2527%2520or%2520result%3D%2527FAILURE%2527%5D%5B1%5D"

  def self.execute
    if File.exist?(DATA_FILE)
      last_build = Build.new(*File.read(DATA_FILE).split(':'))
    else
      last_build = Build.empty
    end

    agent = Mechanize.new
    response = agent.get(CURRENT_BUILD_URL)
    current_build_info = XmlSimple.xml_in(response.body)
    current_build = Build.new(current_build_info['number'][0], current_build_info['result'][0])

    if current_build.number > last_build.number
      if current_build.failed? || current_build.state != last_build.state
        current_build.announce
      end
      current_build.save
    end
  end
end

class Build
  attr_reader :number, :state


  def self.empty
    Build.new(-1, 'NONE')
  end

  def initialize(number, state)
    @number = number.to_i
    @state = state
  end

  def announce
    case @state
    when 'SUCCESS'
      `afplay #{Dir.pwd}/build_fixed.wav`
    when 'FAILURE'
      `afplay #{Dir.pwd}/build_failed.wav`
    else
      raise 'Unrecognized state'
    end
  end

  def failed?
    state == 'FAILURE'
  end

  def save
    File.open(DATA_FILE, 'w') {|f| f << self.to_s }
  end

  def to_s
    "#{number}:#{state}"
  end
end

Poller.execute