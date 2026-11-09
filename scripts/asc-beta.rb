#!/usr/bin/env ruby
# =============================================================================
# APP STORE CONNECT — HAND A VALID BUILD TO THE TESTERS, AND READ WHAT THEY SENT BACK
# =============================================================================
# The Studio upload ends at "build VALID" (scripts/asc-build-state.rb): the build reaches the
# internal testers only, with no "What to Test" and no notice. This is the other half
# (founder 2026-11-09: "Wenn ein neuer TestFlight herauskommt, sollen die Testerinnen eine
# Nachricht bekommen … Feedback bzw. Crashreport direkt senden").
#
#   ruby scripts/asc-beta.rb distribute <build> <version> <group name> <release file>
#       1. "What to Test" (en-US) from the release file: the part above "Bump this file" plus the
#          device questions; Apple's limit is 4000 characters.
#       2. Testers are told when the build is available (buildBetaDetail.autoNotifyEnabled).
#       3. The build joins the named tester group — the group behind the public link.
#       4. An external group needs Beta App Review: the build is submitted; "already submitted"
#          or "not needed" is reported, not failed.
#   ruby scripts/asc-beta.rb feedback [days]
#       The screenshot and crash feedback testers sent from TestFlight in the last N days
#       (default 7), as Markdown on stdout, crash logs included. Tester names and e-mail
#       addresses are never printed: feedback is read for the product, not for the person.
#
# Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_CONTENT (the .p8 text), APP_ID — the same as
# asc-build-state.rb, whose sign-in this repeats. The key is never printed.
#
# ⚠️ Written 2026-11-09 against Apple's documented resources (betaBuildLocalizations,
# buildBetaDetails, betaGroups, betaAppReviewSubmissions, betaFeedbackScreenshotSubmissions,
# betaFeedbackCrashSubmissions). It has NOT run against App Store Connect yet: no key exists in a
# cloud session. Its first real run is the measurement; read the step log before trusting it.
# Wiring it into .github/workflows/studio-testflight.yml is founder-gated.
# =============================================================================

require 'jwt'
require 'openssl'
require 'net/http'
require 'uri'
require 'json'
require 'time'

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
WHATS_NEW_LIMIT = 4000

def token
  key = OpenSSL::PKey.read(KEY)
  JWT.encode({ iss: ISSUER, exp: Time.now.to_i + 15 * 60, aud: 'appstoreconnect-v1' },
             key, 'ES256', { kid: KEY_ID })
rescue StandardError => e
  puts "::error title=ASC::the private key does not sign an ES256 token (#{e.class})"
  exit 1
end

# One request; answers [HTTP status, parsed body or {}]. A transport error is status 0.
def call(method, path, body = nil)
  uri = URI(path.start_with?('http') ? path : "https://api.appstoreconnect.apple.com#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 15
  http.read_timeout = 60
  request = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch }.fetch(method).new(uri)
  request['Authorization'] = "Bearer #{token}"
  if body
    request['Content-Type'] = 'application/json'
    request.body = JSON.generate(body)
  end
  response = http.request(request)
  parsed = response.body.to_s.empty? ? {} : (JSON.parse(response.body) rescue {})
  [response.code.to_i, parsed]
rescue StandardError => e
  [0, { 'transport' => e.class.to_s }]
end

# Apple's own error titles, never the request: they name the reason without echoing data.
def reason(parsed)
  (parsed['errors'] || []).map { |e| e['title'] || e['code'] }.compact.join('; ')
end

def summary(lines)
  path = ENV['GITHUB_STEP_SUMMARY'].to_s
  return if path.empty?
  File.open(path, 'a') { |f| f.puts(lines) }
end

# The release file without the instructions for whoever uploads: everything above
# "Bump this file", then the device questions from "Five things" on.
def whats_new(path)
  text = File.read(path, encoding: "UTF-8")
  lines = text.lines
  cut = lines.index { |l| l.start_with?('Bump this file') }
  questions = lines.index { |l| l.start_with?('Five things') }
  kept = cut ? lines[0...cut] : lines
  kept += ["\n"] + lines[questions..] if cut && questions && questions > cut
  out = kept.join.strip
  out.length > WHATS_NEW_LIMIT ? out[0, WHATS_NEW_LIMIT - 1] + '…' : out
end

def find_build(build, version)
  query = "filter%5Bapp%5D=#{APP_ID}&filter%5Bversion%5D=#{build}" \
          "&filter%5BpreReleaseVersion.version%5D=#{URI.encode_www_form_component(version)}&limit=1"
  code, parsed = call(:get, "/v1/builds?#{query}")
  data = parsed['data'] || []
  unless code == 200 && !data.empty?
    puts "::error title=ASC::build #{build} (#{version}) not found (HTTP #{code}) #{reason(parsed)}"
    exit 1
  end
  data[0]['id']
end

def distribute(build, version, group_name, release_file)
  build_id = find_build(build, version)
  notes = whats_new(release_file)
  failures = []

  # 1. What to Test
  code, parsed = call(:get, "/v1/builds/#{build_id}/betaBuildLocalizations")
  existing = (parsed['data'] || []).find { |l| l.dig('attributes', 'locale') == 'en-US' }
  code, parsed = if existing
                   call(:patch, "/v1/betaBuildLocalizations/#{existing['id']}",
                        { data: { type: 'betaBuildLocalizations', id: existing['id'], attributes: { whatsNew: notes } } })
                 else
                   call(:post, '/v1/betaBuildLocalizations',
                        { data: { type: 'betaBuildLocalizations', attributes: { locale: 'en-US', whatsNew: notes },
                                  relationships: { build: { data: { type: 'builds', id: build_id } } } } })
                 end
  if [200, 201].include?(code)
    puts "[ASC] What to Test set (#{notes.length} characters)"
  else
    failures << "What to Test: HTTP #{code} #{reason(parsed)}"
  end

  # 2. Tell the testers when it is available
  code, parsed = call(:get, "/v1/builds/#{build_id}/buildBetaDetail")
  detail_id = parsed.dig('data', 'id')
  if detail_id
    code, parsed = call(:patch, "/v1/buildBetaDetails/#{detail_id}",
                        { data: { type: 'buildBetaDetails', id: detail_id, attributes: { autoNotifyEnabled: true } } })
    code == 200 ? puts('[ASC] testers are notified when the build is available') : failures << "notify: HTTP #{code} #{reason(parsed)}"
  else
    failures << "notify: no buildBetaDetail (HTTP #{code}) #{reason(parsed)}"
  end

  # 3. Into the group
  code, parsed = call(:get, "/v1/betaGroups?filter%5Bapp%5D=#{APP_ID}&filter%5Bname%5D=#{URI.encode_www_form_component(group_name)}&limit=1")
  group = (parsed['data'] || [])[0]
  if group.nil?
    puts "::error title=ASC::no tester group named \"#{group_name}\" (HTTP #{code}) — create it in App Store Connect first"
    exit 1
  end
  external = !group.dig('attributes', 'isInternalGroup')
  code, parsed = call(:post, "/v1/betaGroups/#{group['id']}/relationships/builds",
                      { data: [{ type: 'builds', id: build_id }] })
  code == 204 ? puts("[ASC] build #{build} added to \"#{group_name}\"") : failures << "group: HTTP #{code} #{reason(parsed)}"

  # 4. Beta App Review for an external group
  if external
    code, parsed = call(:post, '/v1/betaAppReviewSubmissions',
                        { data: { type: 'betaAppReviewSubmissions',
                                  relationships: { build: { data: { type: 'builds', id: build_id } } } } })
    case code
    when 201 then puts('[ASC] submitted for Beta App Review')
    when 409, 422 then puts("[ASC] Beta App Review: #{reason(parsed)} (not an error)")
    else failures << "review: HTTP #{code} #{reason(parsed)}"
    end
  end

  if failures.empty?
    summary(["## TestFlight: build #{build} handed to \"#{group_name}\"", '- What to Test set, testers notified on availability'])
    exit 0
  end
  failures.each { |f| puts "::warning title=TestFlight distribution::#{f}" }
  summary(["## TestFlight: build #{build} uploaded, distribution incomplete"] + failures.map { |f| "- #{f}" })
  exit 0 # the upload itself succeeded; a partial hand-over is a warning to act on, not a red run
end

PRIVATE = /email|name|tester/i

def listed(path)
  items = []
  url = path
  while url
    code, parsed = call(:get, url)
    unless code == 200
      puts "::error title=ASC::#{path.split('?').first} HTTP #{code} #{reason(parsed)}"
      exit 1
    end
    items.concat(parsed['data'] || [])
    url = parsed.dig('links', 'next')
  end
  items
end

def feedback(days)
  since = Time.now - days * 86_400
  puts "# TestFlight feedback, last #{days} days (#{Time.now.utc.strftime('%F %R')} UTC)"
  { 'Screenshot feedback' => 'betaFeedbackScreenshotSubmissions',
    'Crash feedback' => 'betaFeedbackCrashSubmissions' }.each do |title, kind|
    items = listed("/v1/apps/#{APP_ID}/#{kind}?limit=50").select do |item|
      created = item.dig('attributes', 'createdDate')
      created.nil? || Time.parse(created) >= since
    end
    puts "\n## #{title}: #{items.size}"
    items.each do |item|
      attrs = (item['attributes'] || {}).reject { |k, _| k.match?(PRIVATE) }
      puts "\n### #{attrs.delete('createdDate')} · #{item['id']}"
      comment = attrs.delete('comment')
      puts "> #{comment.to_s.gsub("\n", "\n> ")}" unless comment.to_s.empty?
      attrs.each { |k, v| puts "- #{k}: #{v}" unless v.nil? || v.is_a?(Hash) || v.is_a?(Array) }
      next unless kind == 'betaFeedbackCrashSubmissions'
      code, parsed = call(:get, "/v1/betaFeedbackCrashSubmissions/#{item['id']}/crashLog")
      log = parsed.dig('data', 'attributes', 'logText')
      puts(log ? "\n```\n#{log}\n```" : "- crash log: HTTP #{code} #{reason(parsed)}")
    end
  end
end

case ARGV[0]
when 'distribute'
  build, version, group_name, release_file = ARGV[1..4]
  if [build, version, group_name, release_file].any? { |a| a.to_s.empty? } || !File.file?(release_file.to_s)
    puts '::error title=ASC::usage: asc-beta.rb distribute <build> <version> <group name> <release file>'
    exit 1
  end
  distribute(build, version, group_name, release_file)
when 'feedback'
  feedback((ARGV[1] || '7').to_i.clamp(1, 90))
else
  puts '::error title=ASC::usage: asc-beta.rb distribute <build> <version> <group> <release file> | feedback [days]'
  exit 1
end
