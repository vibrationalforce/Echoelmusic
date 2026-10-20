#!/usr/bin/env ruby
# =============================================================================
# APP STORE CONNECT — DID THE BUILD LAND, AND WHAT DID APPLE MAKE OF IT?
# =============================================================================
# The Studio upload stopped at "xcodebuild -exportArchive returned 0" (ultra-audit
# 2026-10-20, TF-4/TF-9): a key that cannot sign in, a build Apple renumbered, or a build that
# processing rejects as INVALID were all invisible to the pipeline. The legacy testflight.yml
# polled App Store Connect after every upload; this is that lesson, for Echoel Studio.
#
#   ruby scripts/asc-build-state.rb auth                 # sign in once: GET /v1/apps/<APP_ID>
#   ruby scripts/asc-build-state.rb wait <build> <ver>   # poll until VALID, INVALID or FAILED
#
# Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_CONTENT (the .p8 text), APP_ID.
# The key is read from the environment only and is never printed; only HTTP status codes and
# Apple's public build attributes reach the log.
#
# Exit codes: 0 = signed in / build VALID · 1 = refused (bad key, INVALID/FAILED build, a
# number that is not ours) · 0 with a ::warning:: when processing outlasts the wait — the upload
# itself already succeeded, and Apple's ingest time varies.
#
# `jwt` is a dependency of the fastlane gem the workflow installs before this runs.
# =============================================================================

require 'jwt'
require 'openssl'
require 'net/http'
require 'uri'
require 'json'

def env!(name)
  value = ENV[name].to_s
  if value.empty?
    puts "::error title=ASC::#{name} is empty"
    exit 1
  end
  value
end

KEY_ID = env!('ASC_KEY_ID')
ISSUER = env!('ASC_ISSUER_ID')
KEY = env!('ASC_KEY_CONTENT')
APP_ID = env!('APP_ID')

unless KEY.include?('BEGIN PRIVATE KEY')
  puts '::error title=ASC::APP_STORE_CONNECT_PRIVATE_KEY has no PEM header (BEGIN PRIVATE KEY)'
  exit 1
end

def token
  key = OpenSSL::PKey.read(KEY)
  JWT.encode({ iss: ISSUER, exp: Time.now.to_i + 15 * 60, aud: 'appstoreconnect-v1' },
             key, 'ES256', { kid: KEY_ID })
rescue StandardError => e
  puts "::error title=ASC::the private key does not sign an ES256 token (#{e.class})"
  exit 1
end

def get(path)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 15
  http.read_timeout = 30
  request = Net::HTTP::Get.new(uri)
  request['Authorization'] = "Bearer #{token}"
  response = http.request(request)
  [response.code.to_i, response.body.to_s]
rescue StandardError => e
  [0, e.class.to_s]
end

def summary(lines)
  path = ENV['GITHUB_STEP_SUMMARY'].to_s
  return if path.empty?
  File.open(path, 'a') { |f| f.puts(lines) }
end

case ARGV[0]
when 'auth'
  code, = get("/v1/apps/#{APP_ID}")
  if code == 200
    puts "[OK] App Store Connect accepts the key (app #{APP_ID})"
    exit 0
  end
  hint = { 401 => 'the key, key ID or issuer ID is wrong, or the key was revoked',
           403 => 'the key lacks the App Manager or Admin role',
           404 => 'this key cannot see the app' }[code] || 'no usable answer'
  puts "::error title=ASC sign-in failed::HTTP #{code} — #{hint}"
  exit 1

when 'wait'
  build = ARGV[1].to_s
  version = ARGV[2].to_s
  if build.empty? || version.empty?
    puts '::error title=ASC::usage: wait <build number> <marketing version>'
    exit 1
  end
  query = "filter%5Bapp%5D=#{APP_ID}&filter%5Bversion%5D=#{build}" \
          "&filter%5BpreReleaseVersion.version%5D=#{URI.encode_www_form_component(version)}&limit=1"
  last_state = nil
  40.times do |i|
    code, body = get("/v1/builds?#{query}")
    if code == 200
      data = (JSON.parse(body)['data'] || []) rescue []
      unless data.empty?
        attrs = data[0]['attributes'] || {}
        state = attrs['processingState'] || 'UNKNOWN'
        if state != last_state
          puts "[ASC] build #{build} (#{version}) id=#{data[0]['id']} state=#{state} " \
               "uploaded=#{attrs['uploadedDate']} nonExemptEncryption=#{attrs['usesNonExemptEncryption'].inspect}"
          last_state = state
        end
        case state
        when 'VALID'
          summary(["## App Store Connect: build #{build} (#{version}) is VALID",
                   "- uploaded: `#{attrs['uploadedDate']}`",
                   "- usesNonExemptEncryption: `#{attrs['usesNonExemptEncryption'].inspect}`"])
          exit 0
        when 'INVALID', 'FAILED'
          puts "::error title=ASC processing::build #{build} (#{version}) is #{state}; Apple's e-mail names the reason"
          summary(["## App Store Connect: build #{build} (#{version}) is #{state}"])
          exit 1
        end
      end
    elsif code == 401 || code == 403
      puts "::error title=ASC::HTTP #{code} while polling — the key stopped working mid-run"
      exit 1
    end
    puts "[attempt #{i + 1}/40] build #{build} #{last_state ? "still #{last_state}" : 'not visible yet'} (HTTP #{code}); next look in 45 s"
    sleep 45
  end
  puts "::warning title=ASC slow::build #{build} was uploaded but is #{last_state || 'not visible'} after 30 min — check TestFlight"
  summary(["## App Store Connect: build #{build} uploaded, #{last_state || 'not visible'} after 30 min (non-fatal)"])
  exit 0

else
  puts '::error title=ASC::usage: asc-build-state.rb auth | wait <build> <version>'
  exit 1
end
