# frozen_string_literal: true

require "spaceship"

Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
  key_id: ENV.fetch("ASC_KEY_ID", "QLSK2QDQ67"),
  issuer_id: ENV.fetch("ASC_ISSUER_ID", "0937aa2d-d63f-411e-928e-0ec39732c589"),
  filepath: File.expand_path(ENV.fetch("ASC_KEY_PATH", "~/.appstoreconnect/AuthKey_QLSK2QDQ67.p8"))
)

targets = [
  {
    bundle_id: "me.ph7.Succeed-AI",
    platform: Spaceship::ConnectAPI::Platform::IOS,
    expected: {
      "APP_IPHONE_67" => 3,
      "APP_IPAD_PRO_3GEN_129" => 1
    }
  },
  {
    bundle_id: "me.ph7.SucceedAI",
    platform: Spaceship::ConnectAPI::Platform::MAC_OS,
    expected: { "APP_DESKTOP" => 5 }
  }
]

if ENV["TARGET_BUNDLE_ID"]
  targets.select! { |target| target[:bundle_id] == ENV["TARGET_BUNDLE_ID"] }
  abort("Unknown TARGET_BUNDLE_ID: #{ENV['TARGET_BUNDLE_ID']}") if targets.empty?
end

targets.each do |target|
  app = Spaceship::ConnectAPI::App.find(target[:bundle_id])
  abort("App Store Connect app not found: #{target[:bundle_id]}") unless app

  submission = app.get_in_progress_review_submission(platform: target[:platform])
  if submission
    abort("Cannot safely withdraw #{target[:bundle_id]} while state is #{submission.state}") unless submission.state == "WAITING_FOR_REVIEW"

    canceled = submission.cancel_submission
    puts "Withdrawing #{target[:bundle_id]} review submission: #{canceled.state}"

    60.times do
      sleep 2
      break unless app.get_in_progress_review_submission(platform: target[:platform])
    end
    abort("Timed out withdrawing #{target[:bundle_id]}") if app.get_in_progress_review_submission(platform: target[:platform])
  end

  version = app.get_app_store_versions(includes: "build", limit: 20).find do |candidate|
    candidate.platform == target[:platform] && candidate.version_string == "1.0"
  end
  abort("Version 1.0 not found for #{target[:bundle_id]}") unless version

  actual_counts = {}
  version.get_app_store_version_localizations.each do |localization|
    localization.get_app_screenshot_sets(includes: "appScreenshots").each do |set|
      screenshots = set.app_screenshots || []
      groups = screenshots.group_by do |screenshot|
        checksum = screenshot.source_file_checksum.to_s
        checksum.empty? ? screenshot.file_name : checksum
      end

      groups.each_value do |duplicates|
        duplicates.drop(1).each do |duplicate|
          duplicate.delete!
          puts "Deleted duplicate #{set.screenshot_display_type}/#{duplicate.file_name}"
        end
      end

      actual_counts[set.screenshot_display_type] = groups.length
    end
  end

  target[:expected].each do |display_type, expected_count|
    actual_count = actual_counts.fetch(display_type, 0)
    abort("#{target[:bundle_id]} #{display_type}: expected #{expected_count} unique screenshots, found #{actual_count}") unless actual_count == expected_count
  end

  puts "Clean screenshot counts verified for #{target[:bundle_id]}"
end
