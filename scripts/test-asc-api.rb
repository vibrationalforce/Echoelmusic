#!/usr/bin/env ruby
# =============================================================================
# APP STORE CONNECT API COMMUNICATION TEST
# =============================================================================
# Tests actual API connectivity with your credentials
#
# Usage:
#   export ASC_KEY_ID=xxx
#   export ASC_ISSUER_ID=xxx
#   export ASC_KEY_CONTENT='-----BEGIN PRIVATE KEY-----...'
#   ruby test-asc-api.rb
# =============================================================================

require 'jwt'
require 'net/http'
require 'uri'
require 'json'

puts "============================================"
puts "  APP STORE CONNECT API TEST"
puts "============================================"
puts ""

# Get credentials
key_id = ENV['ASC_KEY_ID'] || ENV['APP_STORE_CONNECT_KEY_ID']
issuer_id = ENV['ASC_ISSUER_ID'] || ENV['APP_STORE_CONNECT_ISSUER_ID']
key_content = ENV['ASC_KEY_CONTENT'] || ENV['APP_STORE_CONNECT_PRIVATE_KEY']

# Validate
errors = []
errors << "ASC_KEY_ID not set" if key_id.nil? || key_id.empty?
errors << "ASC_ISSUER_ID not set" if issuer_id.nil? || issuer_id.empty?
errors << "ASC_KEY_CONTENT not set" if key_content.nil? || key_content.empty?

if errors.any?
  puts "[FAIL] Missing credentials:"
  errors.each { |e| puts "  - #{e}" }
  exit 1
end

puts "[OK] Credentials loaded"
puts "  Key ID: #{key_id}"
puts "  Issuer: #{issuer_id[0..7]}..."
puts ""

# Generate JWT
puts "Generating JWT token..."
begin
  private_key = OpenSSL::PKey.read(key_content)

  payload = {
    iss: issuer_id,
    exp: Time.now.to_i + 20 * 60, # 20 minutes
    aud: "appstoreconnect-v1"
  }

  token = JWT.encode(payload, private_key, 'ES256', { kid: key_id })
  puts "[OK] JWT generated (#{token.length} chars)"
rescue => e
  puts "[FAIL] JWT generation failed: #{e.message}"
  puts ""
  puts "Possible causes:"
  puts "  - Invalid private key format"
  puts "  - Key content has wrong line breaks"
  puts "  - Key is not an ES256 key"
  exit 1
end

# Test API
puts ""
puts "Testing API connection..."
uri = URI('https://api.appstoreconnect.apple.com/v1/apps')

begin
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.read_timeout = 10

  request = Net::HTTP::Get.new(uri)
  request['Authorization'] = "Bearer #{token}"
  request['Content-Type'] = 'application/json'

  response = http.request(request)

  puts ""
  puts "Response: HTTP #{response.code}"

  case response.code.to_i
  when 200
    data = JSON.parse(response.body)
    apps = data['data'] || []
    puts "[OK] API COMMUNICATION SUCCESSFUL!"
    puts ""
    puts "Found #{apps.length} app(s):"
    apps.each do |app|
      puts "  - #{app['attributes']['name']} (#{app['attributes']['bundleId']})"
    end
  when 401
    puts "[FAIL] UNAUTHORIZED - Invalid credentials"
    puts ""
    puts "Check:"
    puts "  1. Key ID matches your .p8 file name (AuthKey_XXXX.p8)"
    puts "  2. Issuer ID is from App Store Connect → Users → API Keys"
    puts "  3. Private key is the full PEM content"
  when 403
    puts "[FAIL] FORBIDDEN - Key lacks permissions"
    puts ""
    puts "Check:"
    puts "  1. API key has Admin or App Manager role"
    puts "  2. Key is not revoked"
  when 429
    puts "[WARN] RATE LIMITED - Too many requests"
    puts "Wait and try again"
  else
    puts "[FAIL] Unexpected response"
    puts "Body: #{response.body[0..500]}"
  end

rescue => e
  puts "[FAIL] Connection error: #{e.message}"
end

puts ""
puts "============================================"
