#! /usr/bin/env ruby
#
#   check-jenkins
#
# DESCRIPTION:
#   This plugin checks that the Jenkins Metrics ping url returns pong with status 200 OK
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: rest-client
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2015, Cornel Foltea cornel.foltea@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'

class JenkinsMetricsPingPongChecker < Sensu::Plugin::Check::CLI
  option :server,
         description: 'Jenkins Host',
         short: '-s SERVER',
         long: '--server SERVER',
         default: 'localhost'

  option :port,
         description: 'Jenkins Port',
         short: '-p PORT',
         long: '--port PORT',
         default: '8000'

  option :token,
         description: 'Metrics token',
         short: '-t TOKEN',
         long: '--token TOKEN',
         default: ''

  def run
    r = RestClient::Resource.new("http://#{config[:server]}:#{config[:port]}/metrics/#{config[:token]}/ping", timeout: 5).get
    if r.code == 200 && r.body.include?('pong')
      ok 'Jenkins Service is up'
    else
      critical 'Jenkins Service is not responding'
    end
  rescue Errno::ECONNREFUSED
    critical 'Jenkins Service is not responding'
  rescue RestClient::RequestTimeout
    critical 'Jenkins Service Connection timed out'
  end
end
