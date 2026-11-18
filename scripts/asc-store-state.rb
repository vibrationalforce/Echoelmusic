#!/usr/bin/env ruby
# =============================================================================
# APP STORE CONNECT — WHAT DOES THE STORE RECORD SAY TODAY? (READS ONLY)
# =============================================================================
# The store page is filled in by hand, and the repository holds the text that is meant to be
# there (fastlane/metadata). Nothing compared the two, and a plan for the first submission
# rested on guesses: is there a version in preparation, which fields are filled, which
# questions of the age rating are unanswered, does the purchase exist.
#
# This script answers those questions and changes nothing: it only ever sends GET.
#
#   ruby scripts/asc-store-state.rb             # read the record, print the state
#   ruby scripts/asc-store-state.rb --selftest  # offline, no key, no network
#
# Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_CONTENT (the .p8 text), APP_ID.
# Optional: PRODUCT_ID (the one purchase), BUNDLE_IDS (comma-separated identifiers to look up).
#
# THE LOG IS PUBLIC. What reaches it: states, version numbers, locales, lengths, whether a
# field equals the repository's file, the age rating's answers (the store shows their result),
# the capability types of the identifiers named in BUNDLE_IDS. What never does: a contact
# name, mail address or phone number, a demo account, the text of a review note, a tester, an
# identifier or product that was not asked for (those are counted, not named), key material.
#
# A read that Apple refuses is one line with the HTTP status and Apple's public error code;
# the other reads still run. Only a failed sign-in ends the run with exit code 1.
# No gem is needed: the ES256 token is signed with OpenSSL directly.
# =============================================================================

require 'openssl'
require 'net/http'
require 'uri'
require 'json'

module StoreState
  HOST = 'api.appstoreconnect.apple.com'
  TOKEN_SECONDS = 10 * 60 # Apple refuses a token that lives longer than 20 minutes.

  VERSION_FIELDS = {
    'description' => 'description.txt', 'keywords' => 'keywords.txt',
    'promotionalText' => 'promotional_text.txt', 'whatsNew' => 'release_notes.txt',
    'supportUrl' => 'support_url.txt', 'marketingUrl' => 'marketing_url.txt'
  }.freeze
  INFO_FIELDS = {
    'name' => 'name.txt', 'subtitle' => 'subtitle.txt', 'privacyPolicyUrl' => 'privacy_url.txt'
  }.freeze
  CONTACT_FIELDS = %w[contactFirstName contactLastName contactPhone contactEmail].freeze

  def self.base64url(bytes)
    [bytes].pack('m0').tr('+/', '-_').delete('=')
  end

  # An ES256 JSON Web Token: the signature is r and s as two 32-byte numbers, not OpenSSL's DER.
  def self.token(key_pem, key_id, issuer, now = Time.now.to_i)
    key = OpenSSL::PKey.read(key_pem)
    header = { alg: 'ES256', kid: key_id, typ: 'JWT' }
    claims = { iss: issuer, iat: now, exp: now + TOKEN_SECONDS, aud: 'appstoreconnect-v1' }
    signed = [header, claims].map { |part| base64url(JSON.generate(part)) }.join('.')
    der = key.sign(OpenSSL::Digest.new('SHA256'), signed)
    numbers = OpenSSL::ASN1.decode(der).value.map { |number| number.value.to_s(2).rjust(32, "\x00".b) }
    "#{signed}.#{base64url(numbers.join)}"
  end

  def self.query(path, parameters)
    "#{path}?#{URI.encode_www_form(parameters)}"
  end

  # Text as it may be printed: one line, no control characters, bounded.
  def self.plain(value)
    value.to_s.gsub(/[[:cntrl:]]/, ' ').strip[0, 160]
  end

  def self.same_text?(store_value, file_value)
    normal = ->(text) { text.to_s.gsub("\r\n", "\n").strip }
    normal.call(store_value) == normal.call(file_value)
  end

  # Reads the record through `fetch` (path -> [status, body]) and collects the lines to print.
  class Report
    attr_reader :lines, :signed_in

    def initialize(fetch:, app_id:, product_id:, bundle_ids:, metadata:, entitlements: {})
      @fetch = fetch
      @app_id = app_id
      @product_id = product_id
      @bundle_ids = bundle_ids
      @metadata = metadata
      @entitlements = entitlements
      @lines = []
      @signed_in = false
    end

    def run
      app = read('the app', "/v1/apps/#{@app_id}")
      return self unless app

      @signed_in = true
      attributes = app.dig('data', 'attributes') || {}
      say "app: primary locale #{StoreState.plain(attributes['primaryLocale'])}"
      versions
      infos
      purchases
      identifiers
      self
    end

    private

    def say(line)
      @lines << line
    end

    def read(label, path)
      status, body = @fetch.call(path)
      parsed = begin
        JSON.parse(body)
      rescue StandardError
        nil
      end
      if status == 200 && parsed.is_a?(Hash)
        if parsed.dig('links', 'next')
          say "  NOTE #{label}: more entries exist than one page holds; only the first page was read"
        end
        return parsed
      end
      error = parsed.is_a?(Hash) ? (parsed['errors'] || []).first : nil
      code = error.is_a?(Hash) ? StoreState.plain(error['code']) : ''
      say "  NOT READ #{label}: HTTP #{status}#{code.empty? ? '' : " (#{code})"}"
      nil
    end

    def list(label, path)
      parsed = read(label, path)
      data = parsed && parsed['data']
      data.is_a?(Array) ? data : []
    end

    def state_of(attributes)
      StoreState.plain(attributes['appVersionState'] || attributes['appStoreState'] || attributes['state'] || 'unknown')
    end

    def versions
      found = list('the versions', StoreState.query("/v1/apps/#{@app_id}/appStoreVersions", 'limit' => 20))
      say "versions: #{found.length}"
      found.first(3).each { |version| version_detail(version) }
      say "  NOTE only the first 3 of #{found.length} versions are read in detail" if found.length > 3
    end

    def version_detail(version)
      attributes = version['attributes'] || {}
      identifier = version['id']
      say "version #{StoreState.plain(attributes['versionString'])} (#{StoreState.plain(attributes['platform'])}): " \
          "state #{state_of(attributes)}, release #{StoreState.plain(attributes['releaseType'] || 'not set')}"
      build = read('the attached build', "/v1/appStoreVersions/#{identifier}/build")
      if build
        number = build.dig('data', 'attributes', 'version')
        say number ? "  build attached: #{StoreState.plain(number)}" : '  build attached: none'
      end
      review_detail(identifier)
      localizations = list('the version texts',
                           StoreState.query("/v1/appStoreVersions/#{identifier}/appStoreVersionLocalizations", 'limit' => 50))
      say "  languages of the version: #{localizations.length}"
      localizations.each do |localization|
        fields(localization, VERSION_FIELDS)
        screenshots(localization)
      end
    end

    def fields(localization, mapping)
      attributes = localization['attributes'] || {}
      locale = StoreState.plain(attributes['locale'])
      mapping.each do |field, file|
        value = attributes[field].to_s
        wanted = @metadata.call(locale, file)
        against = if wanted.nil?
                    'no file in the repository'
                  elsif StoreState.same_text?(value, wanted)
                    'equals the repository'
                  else
                    "DIFFERS from the repository (#{wanted.strip.length} characters there)"
                  end
        filled = value.strip.empty? ? 'EMPTY' : "#{value.strip.length} characters"
        say "    #{locale} #{field}: #{filled}, #{against}"
      end
    end

    def screenshots(localization)
      locale = StoreState.plain((localization['attributes'] || {})['locale'])
      sets = list('the screenshot sets',
                  StoreState.query("/v1/appStoreVersionLocalizations/#{localization['id']}/appScreenshotSets", 'limit' => 50))
      if sets.empty?
        say "    #{locale} screenshots (older resource): no set"
        return
      end
      sets.each do |set|
        kind = StoreState.plain((set['attributes'] || {})['screenshotDisplayType'])
        shots = list('the screenshots', StoreState.query("/v1/appScreenshotSets/#{set['id']}/appScreenshots", 'limit' => 50))
        say "    #{locale} screenshots #{kind}: #{shots.length}"
      end
    end

    def review_detail(version_identifier)
      detail = read('the review information', "/v1/appStoreVersions/#{version_identifier}/appStoreReviewDetail")
      return unless detail

      attributes = detail.dig('data', 'attributes')
      if attributes.nil?
        say '  review information: none'
        return
      end
      complete = CONTACT_FIELDS.all? { |field| !attributes[field].to_s.strip.empty? }
      say "  review information: contact #{complete ? 'complete' : 'INCOMPLETE'}, " \
          "note #{attributes['notes'].to_s.strip.length} characters, " \
          "demo account required: #{StoreState.plain(attributes['demoAccountRequired'].inspect)}"
    end

    def infos
      found = list('the app information', StoreState.query("/v1/apps/#{@app_id}/appInfos", 'limit' => 10))
      say "app information records: #{found.length}"
      found.each do |info|
        attributes = info['attributes'] || {}
        identifier = info['id']
        say "app information: state #{state_of(attributes)}, " \
            "age rating #{StoreState.plain(attributes['appStoreAgeRating'] || 'not derived')}"
        %w[primaryCategory secondaryCategory].each do |relation|
          category = read("the #{relation}", "/v1/appInfos/#{identifier}/#{relation}")
          say "  #{relation}: #{StoreState.plain(category.dig('data', 'id') || 'none')}" if category
        end
        list('the app information texts', StoreState.query("/v1/appInfos/#{identifier}/appInfoLocalizations", 'limit' => 50))
          .each { |localization| fields(localization, INFO_FIELDS) }
        age_rating(identifier)
      end
    end

    def age_rating(info_identifier)
      declaration = read('the age rating', "/v1/appInfos/#{info_identifier}/ageRatingDeclaration")
      return unless declaration

      attributes = declaration.dig('data', 'attributes') || {}
      unanswered = attributes.select { |_, value| value.nil? }.keys.sort
      say "  age rating: #{attributes.length} questions, #{unanswered.length} unanswered"
      attributes.keys.sort.each do |name|
        value = attributes[name]
        say "    #{StoreState.plain(name)}: #{value.nil? ? 'UNANSWERED' : StoreState.plain(value)}"
      end
    end

    def purchases
      found = list('the purchases', StoreState.query("/v1/apps/#{@app_id}/inAppPurchasesV2", 'limit' => 50))
      ours = found.find { |purchase| (purchase['attributes'] || {})['productId'] == @product_id }
      if ours
        attributes = ours['attributes']
        say "purchase #{@product_id}: #{StoreState.plain(attributes['inAppPurchaseType'])}, " \
            "state #{StoreState.plain(attributes['state'])}, " \
            "family sharing #{StoreState.plain(attributes['familySharable'].inspect)}"
      else
        say "purchase #{@product_id}: not created"
      end
      others = found.length - (ours ? 1 : 0)
      say "other purchases on this app: #{others} (not named here)" if others.positive?
    end

    def identifiers
      @bundle_ids.each do |wanted|
        found = list('the identifiers',
                     StoreState.query('/v1/bundleIds', 'filter[identifier]' => wanted, 'limit' => 200))
        exact = found.find { |entry| (entry['attributes'] || {})['identifier'] == wanted }
        unless exact
          say "identifier #{wanted}: not registered (or not visible to this key)"
          next
        end
        capabilities = list('the capabilities',
                            StoreState.query("/v1/bundleIds/#{exact['id']}/bundleIdCapabilities", 'limit' => 200))
        types = capabilities.map { |entry| StoreState.plain((entry['attributes'] || {})['capabilityType']) }.sort
        say "identifier #{wanted}: capabilities #{types.empty? ? 'none' : types.join(', ')}"
        keys = @entitlements[wanted]
        say "  entitlements in the repository: #{keys.empty? ? 'none' : keys.join(', ')}" if keys
      end
    end
  end

  # A repository file as UTF-8 text, whatever the runner's locale is (German text has umlauts,
  # and under LANG=C Ruby would read it as ASCII and never find it equal to Apple's answer).
  def self.read_text(path)
    File.file?(path) ? File.read(path, encoding: 'UTF-8').scrub : nil
  end

  # The top-level keys of an entitlements file, by name only.
  def self.entitlement_keys(path)
    text = read_text(path)
    text && text.scan(%r{^\t<key>([^<]+)</key>}).flatten.sort
  end

  def self.live_fetch(key_pem, key_id, issuer)
    lambda do |path|
      uri = URI("https://#{HOST}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 15
      http.read_timeout = 30
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{token(key_pem, key_id, issuer)}"
      response = http.request(request)
      [response.code.to_i, response.body.to_s]
    rescue StandardError => e
      [0, JSON.generate('errors' => [{ 'code' => e.class.to_s }])]
    end
  end

  def self.main
    names = %w[ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_CONTENT APP_ID]
    missing = names.select { |name| ENV[name].to_s.empty? }
    unless missing.empty?
      puts "::error title=Store state::empty: #{missing.join(', ')}"
      return 1
    end
    unless ENV['ASC_KEY_CONTENT'].include?('BEGIN PRIVATE KEY')
      puts '::error title=Store state::the private key has no PEM header (BEGIN PRIVATE KEY)'
      return 1
    end
    root = File.expand_path('..', __dir__)
    metadata = lambda do |locale, file|
      path = File.join(root, 'fastlane', 'metadata', locale, file)
      locale.match?(/\A[A-Za-z-]+\z/) ? read_text(path) : nil
    end
    bundle_ids = ENV['BUNDLE_IDS'].to_s.split(',').map(&:strip).reject(&:empty?)
    entitlement_files = {
      'com.echoelmusic.app' => 'EchoelStudio/Support/App/EchoelStudio.entitlements',
      'com.echoelmusic.app.auv3' => 'EchoelStudio/Support/Plugins/EchoelPlugins.entitlements'
    }
    entitlements = {}
    bundle_ids.each do |identifier|
      relative = entitlement_files[identifier]
      keys = relative && entitlement_keys(File.join(root, relative))
      entitlements[identifier] = keys if keys
    end
    report = Report.new(
      fetch: live_fetch(ENV['ASC_KEY_CONTENT'], ENV['ASC_KEY_ID'], ENV['ASC_ISSUER_ID']),
      app_id: ENV['APP_ID'],
      product_id: ENV['PRODUCT_ID'].to_s.empty? ? 'com.echoelmusic.app.pro' : ENV['PRODUCT_ID'],
      bundle_ids: bundle_ids, metadata: metadata, entitlements: entitlements
    ).run
    puts report.lines
    summary = ENV['GITHUB_STEP_SUMMARY'].to_s
    unless summary.empty?
      File.open(summary, 'a') { |file| file.puts(['```', *report.lines, '```']) }
    end
    return 0 if report.signed_in

    puts '::error title=Store state::App Store Connect did not answer the first read; see the NOT READ line above'
    1
  end

  def self.selftest
    failures = []
    check = ->(name, condition) { failures << name unless condition }

    # The token: three parts, ten minutes, and a signature the key's public half accepts.
    key = OpenSSL::PKey::EC.generate('prime256v1')
    made = token(key.to_pem, 'KEYID', 'ISSUER', 1_000)
    head, body, signature = made.split('.')
    decode = ->(part) { part.tr('-_', '+/').ljust((part.length + 3) / 4 * 4, '=').unpack1('m') }
    claims = JSON.parse(decode.call(body))
    check.call('token header', JSON.parse(decode.call(head)) == { 'alg' => 'ES256', 'kid' => 'KEYID', 'typ' => 'JWT' })
    check.call('token claims', claims == { 'iss' => 'ISSUER', 'iat' => 1_000, 'exp' => 1_600, 'aud' => 'appstoreconnect-v1' })
    raw = decode.call(signature)
    check.call('signature is 64 bytes', raw.bytesize == 64)
    der = OpenSSL::ASN1::Sequence([raw[0, 32], raw[32, 32]].map { |half| OpenSSL::ASN1::Integer(OpenSSL::BN.new(half, 2)) }).to_der
    check.call('signature verifies', key.verify(OpenSSL::Digest.new('SHA256'), der, "#{head}.#{body}"))

    secret = %w[reviewer@example.org +4912345 Erika Mustermann hunter2 SECRET-NOTE com.example.other com.other.product]
    answers = {
      '/v1/apps/1' => { 'data' => { 'attributes' => { 'primaryLocale' => 'en-US' } } },
      '/v1/apps/1/appStoreVersions?limit=20' => { 'data' => [{ 'id' => 'V', 'attributes' => {
        'versionString' => '11.0.0', 'platform' => 'IOS', 'appVersionState' => 'PREPARE_FOR_SUBMISSION'
      } }] },
      '/v1/appStoreVersions/V/build' => { 'data' => nil },
      '/v1/appStoreVersions/V/appStoreReviewDetail' => { 'data' => { 'attributes' => {
        'contactFirstName' => 'Erika', 'contactLastName' => 'Mustermann', 'contactPhone' => '+4912345',
        'contactEmail' => 'reviewer@example.org', 'demoAccountName' => 'demo', 'demoAccountPassword' => 'hunter2',
        'demoAccountRequired' => false, 'notes' => 'SECRET-NOTE'
      } } },
      '/v1/appStoreVersions/V/appStoreVersionLocalizations?limit=50' => { 'data' => [{ 'id' => 'L', 'attributes' => {
        'locale' => 'en-US', 'description' => "Same text\r\n", 'keywords' => 'old,words', 'whatsNew' => nil
      } }], 'links' => { 'next' => 'https://example.invalid/next' } },
      '/v1/appStoreVersionLocalizations/L/appScreenshotSets?limit=50' => { 'data' => [] },
      '/v1/apps/1/appInfos?limit=10' => { 'data' => [{ 'id' => 'I', 'attributes' => { 'state' => 'PREPARE_FOR_SUBMISSION' } }] },
      '/v1/appInfos/I/primaryCategory' => { 'data' => { 'id' => 'MUSIC' } },
      '/v1/appInfos/I/secondaryCategory' => { 'data' => nil },
      '/v1/appInfos/I/appInfoLocalizations?limit=50' => { 'data' => [{ 'id' => 'IL', 'attributes' => {
        'locale' => 'en-US', 'name' => 'Echoelmusic', 'subtitle' => 'Another subtitle'
      } }] },
      '/v1/appInfos/I/ageRatingDeclaration' => { 'data' => { 'attributes' => {
        'gambling' => false, 'violenceRealistic' => 'NONE', 'socialMedia' => nil
      } } },
      '/v1/apps/1/inAppPurchasesV2?limit=50' => { 'data' => [{ 'id' => 'P', 'attributes' => {
        'productId' => 'com.other.product', 'state' => 'APPROVED'
      } }] },
      '/v1/bundleIds?filter%5Bidentifier%5D=com.example.app&limit=200' => { 'data' => [
        { 'id' => 'B1', 'attributes' => { 'identifier' => 'com.example.other' } },
        { 'id' => 'B2', 'attributes' => { 'identifier' => 'com.example.app' } }
      ] },
      '/v1/bundleIds/B2/bundleIdCapabilities?limit=200' => { 'data' => [
        { 'attributes' => { 'capabilityType' => 'IN_APP_PURCHASE' } }, { 'attributes' => { 'capabilityType' => 'APP_GROUPS' } }
      ] }
    }
    asked = []
    fetch = lambda do |path|
      asked << path
      answers.key?(path) ? [200, JSON.generate(answers[path])] : [403, '{"errors":[{"code":"FORBIDDEN_ERROR"}]}']
    end
    files = { 'description.txt' => "Same text\n", 'keywords.txt' => 'new,words', 'name.txt' => 'Echoelmusic',
              'subtitle.txt' => 'Music workstation' }
    report = Report.new(fetch: fetch, app_id: '1', product_id: 'com.example.pro', bundle_ids: ['com.example.app'],
                        metadata: ->(_locale, file) { files[file] },
                        entitlements: { 'com.example.app' => ['com.apple.security.application-groups'] }).run
    text = report.lines.join("\n")
    check.call('signed in', report.signed_in)
    check.call('no private value is printed', secret.none? { |value| text.include?(value) })
    check.call('contact complete, note counted', text.include?('contact complete, note 11 characters, demo account required: false'))
    check.call('equal text', text.include?('en-US description: 9 characters, equals the repository'))
    check.call('different text', text.include?('en-US keywords: 9 characters, DIFFERS from the repository (9 characters there)'))
    check.call('empty field', text.include?('en-US whatsNew: EMPTY, no file in the repository'))
    check.call('second page is named', text.include?('NOTE the version texts: more entries exist'))
    check.call('subtitle differs', text.include?('en-US subtitle: 16 characters, DIFFERS'))
    check.call('unanswered question', text.include?('age rating: 3 questions, 1 unanswered') && text.include?('socialMedia: UNANSWERED'))
    check.call('category', text.include?('primaryCategory: MUSIC') && text.include?('secondaryCategory: none'))
    check.call('purchase missing, other counted', text.include?('purchase com.example.pro: not created') &&
               text.include?('other purchases on this app: 1 (not named here)'))
    check.call('capabilities of the asked identifier', text.include?('identifier com.example.app: capabilities APP_GROUPS, IN_APP_PURCHASE'))
    check.call('entitlements beside them', text.include?('entitlements in the repository: com.apple.security.application-groups'))
    check.call('no build', text.include?('build attached: none'))
    check.call('only reads were planned', asked.all? { |path| path.start_with?('/v1/') })

    refused = Report.new(fetch: ->(_path) { [401, '{"errors":[{"code":"NOT_AUTHORIZED"}]}'] }, app_id: '1',
                         product_id: 'p', bundle_ids: [], metadata: ->(_l, _f) {}).run
    check.call('a refused sign-in stops', !refused.signed_in && refused.lines == ['  NOT READ the app: HTTP 401 (NOT_AUTHORIZED)'])

    one_refusal = Report.new(
      fetch: lambda { |path|
        path.include?('ageRatingDeclaration') ? [403, 'not json'] : fetch.call(path)
      }, app_id: '1', product_id: 'com.example.pro', bundle_ids: [], metadata: ->(_l, file) { files[file] }
    ).run
    joined = one_refusal.lines.join("\n")
    check.call('one refusal does not end the run', joined.include?('NOT READ the age rating: HTTP 403') &&
               joined.include?('purchase com.example.pro: not created'))
    require 'tempfile'
    Tempfile.create('store-state') do |file|
      file.binmode
      file.write("Gr\u00F6\u00DFe\n".encode('UTF-8'))
      file.flush
      check.call('a file is read as UTF-8 under any locale', same_text?("Gr\u00F6\u00DFe", read_text(file.path)) &&
                 read_text(file.path).strip.length == 5)
    end
    check.call('a missing file is no text', read_text('/nonexistent/store-state').nil?)
    check.call('plain text is one bounded line', plain("a\nb\u0007#{'x' * 300}").length == 160 && !plain("a\nb").include?("\n"))

    if failures.empty?
      puts 'selftest ok'
      return 0
    end
    puts "selftest FAILED: #{failures.join('; ')}"
    1
  end
end

exit(ARGV.include?('--selftest') ? StoreState.selftest : StoreState.main) if $PROGRAM_NAME == __FILE__
