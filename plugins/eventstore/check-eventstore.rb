#!/usr/bin/env ruby
#
#   check-eventstore
#
# DESCRIPTION:
#   Curl the gossip url and check every "members.[].isAlive" key to know if there is one in false
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: json
#
# NOTES:
#   Based on Check HTTP by Sonian Inc.
#

require 'sensu-plugin/check/cli'
require 'json'
require 'net/http'
require 'net/https'

#
# Check JSON
#
class CheckJson < Sensu::Plugin::Check::CLI
  option :url, short: '-u URL'
  option :header, short: '-H HEADER', long: '--header HEADER'
  option :ssl, short: '-s', boolean: true, default: false
  option :insecure, short: '-k', boolean: true, default: false
  option :user, short: '-U', long: '--username USER'
  option :password, short: '-a', long: '--password PASS'
  option :cert, short: '-c FILE', long: '--cert FILE'
  option :certkey, long: '--cert-key FILE'
  option :cacert, short: '-C FILE', long: '--cacert FILE'
  option :timeout, short: '-t SECS', proc: proc(&:to_i), default: 15

  def run
    uri = URI.parse(config[:url])
    config[:host] = uri.host
    config[:path] = uri.path
    config[:query] = uri.query
    config[:port] = uri.port
    config[:ssl] = uri.scheme == 'https'

    begin
      Timeout.timeout(config[:timeout]) do
        acquire_resource
      end
    rescue Timeout::Error
      critical 'Connection timed out'
    rescue => e
      critical "Connection error: #{e.message}"
    end
  end

  def json_valid?(str)
    JSON.parse(str)
    return true
  rescue JSON::ParserError
    return false
  end

  def acquire_resource
    http = Net::HTTP.new(config[:host], config[:port])

    if config[:ssl]
      http.use_ssl = true
      if config[:cert]
        cert_data = File.read(config[:cert])
        http.cert = OpenSSL::X509::Certificate.new(cert_data)
        if config[:certkey]
          cert_data = File.read(config[:certkey])
        end
        http.key = OpenSSL::PKey::RSA.new(cert_data, nil)
      end
      http.ca_file = config[:cacert] if config[:cacert]
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if config[:insecure]
    end

    req = Net::HTTP::Get.new([config[:path], config[:query]].compact.join('?'))

    unless config[:user].nil? && config[:password].nil?
      req.basic_auth config[:user], config[:password]
    end
    if config[:header]
      config[:header].split(',').each do |header|
        h, v = header.split(':', 2)
        req[h] = v.strip
      end
    end
    res = http.request(req)

    critical res.code unless res.code =~ /^2/
    critical 'invalid JSON from request' unless json_valid?(res.body)

    json = JSON.parse(res.body)

    begin

      raise "could not find key: members" unless json.key?('members')

      nodes_number = 0
      json['members'].each do |member|
          nodes_number = nodes_number + 1
          raise "could not find key: isAlive" unless member.key?('isAlive')
          raise "Member #{member['internalTcpIp']} with role #{member['state']} is not Alive" unless member['isAlive']
      end
      ok "#{nodes_number} nodes alive in the cluster."

#{
#  "members": [
#    {
#      "instanceId": "0ea06dba-a7d6-403b-ad8f-9f13d0ac39be",
#      "timeStamp": "2017-06-09T11:58:40.371646Z",
#      "state": "Slave",
#      "isAlive": true,
#      "internalTcpIp": "10.4.5.179",
#      "internalTcpPort": 1111,
#      "internalSecureTcpPort": 0,
#      "externalTcpIp": "10.4.5.179",
#      "externalTcpPort": 1112,
#      "externalSecureTcpPort": 0,
#      "internalHttpIp": "10.4.5.179",
#      "internalHttpPort": 2113,
#      "externalHttpIp": "10.4.5.179",
#      "externalHttpPort": 2114,
#      "lastCommitPosition": 249877750,
#      "writerCheckpoint": 249891818,
#      "chaserCheckpoint": 249891818,
#      "epochPosition": 239889762,
#      "epochNumber": 15,
#      "epochId": "ca3d6535-752b-4f34-a26e-22c8a4db3d5a",
#      "nodePriority": 0
#    },




#      raise "unexpected value for key: '#{config[:value]}' != '#{leaf}'" unless leaf.to_s == config[:value].to_s
#
#      ok "key has expected value: '#{config[:key]}' = '#{config[:value]}'"
#    rescue => e
#      critical "key check failed: #{e}"
    end
  end
end
