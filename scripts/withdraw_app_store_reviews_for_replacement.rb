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
    version: ENV.fetch("IOS_APP_VERSION", "1.0"),
    build_env: "IOS_BUILD_NUMBER",
    build_number: ENV["IOS_BUILD_NUMBER"]
  },
  {
    name: "macOS",
    bundle_id: "me.ph7.SucceedAI",
    platform: Spaceship::ConnectAPI::Platform::MAC_OS,
    version: ENV.fetch("MAC_APP_VERSION", "1.1"),
    build_env: "MAC_BUILD_NUMBER",
    build_number: ENV["MAC_BUILD_NUMBER"]
  }
]

if ENV["TARGET_BUNDLE_ID"]
  targets.select! { |target| target[:bundle_id] == ENV["TARGET_BUNDLE_ID"] }
  abort("Unknown TARGET_BUNDLE_ID: #{ENV['TARGET_BUNDLE_ID']}") if targets.empty?
end

missing_build_numbers = targets.select { |target| target[:build_number].to_s.strip.empty? }
unless missing_build_numbers.empty?
  variables = missing_build_numbers.map { |target| target[:build_env] }
  abort("Explicit replacement build required: set #{variables.join(' and ')}")
end
unless ENV["CONFIRM_REVIEW_WITHDRAWAL"] == "1"
  abort("Refusing to withdraw review without CONFIRM_REVIEW_WITHDRAWAL=1")
end

targets.each do |target|
  app = Spaceship::ConnectAPI::App.find(target[:bundle_id])
  abort("App Store Connect app not found: #{target[:bundle_id]}") unless app

  replacement = Spaceship::ConnectAPI::Build.all(
    app_id: app.id,
    platform: target[:platform],
    version: target[:version],
    build_number: target[:build_number],
    limit: 10
  ).first
  abort("#{target[:name]} replacement build #{target[:build_number]} is not processed yet") unless replacement
  unless replacement.processing_state == "VALID"
    abort("#{target[:name]} replacement build #{target[:build_number]} is #{replacement.processing_state}")
  end
  if replacement.icon_asset_token.to_s.empty?
    abort("#{target[:name]} replacement build #{target[:build_number]} has no processed App Store icon")
  end

  version = app.get_app_store_versions(includes: "build", limit: 20).find do |candidate|
    candidate.platform == target[:platform] && candidate.version_string == target[:version]
  end
  abort("#{target[:name]} version #{target[:version]} not found") unless version

  submission = app.get_in_progress_review_submission(platform: target[:platform])
  unless submission
    puts "No in-progress #{target[:name]} review submission needs withdrawal."
    next
  end

  expected_state = Spaceship::ConnectAPI::ReviewSubmission::ReviewSubmissionState::WAITING_FOR_REVIEW
  unless submission.state == expected_state
    abort("Refusing to cancel #{target[:name]} submission in state #{submission.state}")
  end

  selected_build = version.get_build
  allow_selected_build = ENV["ALLOW_SELECTED_BUILD_WITHDRAWAL"] == "1"
  if selected_build&.version == target[:build_number] && !allow_selected_build
    puts "#{target[:name]} build #{target[:build_number]} is already selected; no withdrawal performed."
    next
  end

  selected_number = selected_build&.version.to_s.match?(/\A\d+\z/) ? selected_build.version.to_i : nil
  replacement_number = target[:build_number].match?(/\A\d+\z/) ? target[:build_number].to_i : nil
  unless selected_number && replacement_number
    abort("Refusing to compare non-numeric #{target[:name]} build numbers")
  end
  if replacement_number <= selected_number && ENV["ALLOW_NON_NEWER_REPLACEMENT"] != "1"
    abort(
      "Refusing to replace #{target[:name]} build #{selected_number} with non-newer build #{replacement_number}"
    )
  end

  canceled = submission.cancel_submission
  previous_build = selected_build&.version || "none"
  puts "Withdrew #{target[:name]} submission #{submission.id} " \
       "(build #{previous_build}) for valid replacement build #{target[:build_number]}: #{canceled.state}"

  60.times do
    sleep 2
    break unless app.get_in_progress_review_submission(platform: target[:platform])
  end
  if app.get_in_progress_review_submission(platform: target[:platform])
    abort("Timed out waiting for #{target[:name]} review withdrawal")
  end
end
