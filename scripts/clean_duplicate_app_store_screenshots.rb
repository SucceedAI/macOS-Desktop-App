# frozen_string_literal: true

require "spaceship"

Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
  key_id: ENV.fetch("ASC_KEY_ID", "QLSK2QDQ67"),
  issuer_id: ENV.fetch("ASC_ISSUER_ID", "0937aa2d-d63f-411e-928e-0ec39732c589"),
  filepath: File.expand_path(ENV.fetch("ASC_KEY_PATH", "~/.appstoreconnect/AuthKey_QLSK2QDQ67.p8"))
)

targets = [
  {
    name: "iOS",
    bundle_id: "me.ph7.Succeed-AI",
    platform: Spaceship::ConnectAPI::Platform::IOS,
    locale: "en-US",
    sets: {
      "APP_IPHONE_67" => [
        "01-compose-1320x2868.png",
        "02-keyboard-1320x2868.png",
        "03-privacy-1320x2868.png"
      ],
      "APP_IPAD_PRO_3GEN_129" => ["01-compose-ipad-2064x2752.png"]
    }
  },
  {
    name: "macOS",
    bundle_id: "me.ph7.SucceedAI",
    platform: Spaceship::ConnectAPI::Platform::MAC_OS,
    locale: "en-AU",
    sets: {
      "APP_DESKTOP" => [
        "01-type-return-done-2880x1800_DESKTOP.png",
        "02-private-ai-in-every-app-2880x1800_DESKTOP.png",
        "03-menu-bar-control-center-2880x1800_DESKTOP.png",
        "04-on-device-privacy-2880x1800_DESKTOP.png",
        "05-customize-your-flow-2880x1800_DESKTOP.png"
      ]
    }
  }
]

targets.each do |target|
  app = Spaceship::ConnectAPI::App.find(target[:bundle_id])
  abort("App Store Connect app not found: #{target[:bundle_id]}") unless app

  submission = app.get_in_progress_review_submission(platform: target[:platform])
  abort("Refusing to edit #{target[:name]} screenshots while review state is #{submission.state}") if submission

  version = app.get_app_store_versions(limit: 20).find do |candidate|
    candidate.platform == target[:platform] && candidate.version_string == "1.0"
  end
  abort("#{target[:name]} version 1.0 not found") unless version

  localization = version.get_app_store_version_localizations.find { |item| item.locale == target[:locale] }
  abort("#{target[:name]} localization #{target[:locale]} not found") unless localization

  sets = localization.get_app_screenshot_sets(includes: "appScreenshots")
  target[:sets].each do |display_type, expected_files|
    screenshot_set = sets.find { |item| item.screenshot_display_type == display_type }
    abort("#{target[:name]} screenshot set #{display_type} not found") unless screenshot_set

    screenshots = screenshot_set.app_screenshots || []
    abort("#{target[:name]} screenshot set #{display_type} contains unfinished assets") unless screenshots.all?(&:complete?)

    unexpected_files = screenshots.map(&:file_name).uniq - expected_files
    unless unexpected_files.empty?
      abort("#{target[:name]} screenshot set #{display_type} has unexpected files: #{unexpected_files.join(', ')}")
    end

    kept = expected_files.map do |file_name|
      screenshot = screenshots.find { |item| item.file_name == file_name }
      abort("#{target[:name]} screenshot set #{display_type} is missing #{file_name}") unless screenshot
      screenshot
    end
    kept_ids = kept.map(&:id)
    duplicates = screenshots.reject { |item| kept_ids.include?(item.id) }

    duplicates.each(&:delete!)
    screenshot_set.reorder_screenshots(app_screenshot_ids: kept_ids)

    actual_files = nil
    10.times do
      refreshed = localization.get_app_screenshot_sets(includes: "appScreenshots").find do |item|
        item.screenshot_display_type == display_type
      end
      actual_files = (refreshed&.app_screenshots || []).map(&:file_name)
      break if actual_files == expected_files

      sleep 2
    end
    abort("#{target[:name]} screenshot cleanup did not settle for #{display_type}: #{actual_files.inspect}") unless actual_files == expected_files

    puts "#{target[:name]} #{display_type}: kept #{expected_files.length}, removed #{duplicates.length}, order verified."
  end
end
