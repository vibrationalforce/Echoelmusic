# =============================================================================
# ECHOELMUSIC - RUBY DEPENDENCIES
# =============================================================================
# Usage:
#   bundle install            # Install dependencies
#   bundle exec fastlane ...  # Run fastlane
# =============================================================================

source "https://rubygems.org"

# Fastlane - CI/CD automation
gem "fastlane", "~> 2.225"

# XcodeGen - Project generation
# Note: XcodeGen is a Swift CLI tool, installed via:
#   brew install xcodegen
#   OR: mint install yonaskolb/XcodeGen

# Plugins
plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
