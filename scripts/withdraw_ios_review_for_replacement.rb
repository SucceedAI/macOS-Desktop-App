# frozen_string_literal: true

require "spaceship"

Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
  key_id: ENV.fetch("ASC_KEY_ID", "QLSK2QDQ67"),
  issuer_id: ENV.fetch("ASC_ISSUER_ID", "0937aa2d-d63f-411e-928e-0ec39732c589"),
  filepath: File.expand_path(ENV.fetch("ASC_KEY_PATH", "~/.appstoreconnect/AuthKey_QLSK2QDQ67.p8"))
)

bundle_id = "me.ph7.Succeed-AI"
platform = Spaceship::ConnectAPI::Platform::IOS
replacement_number = ENV.fetch("IOS_BUILD_NUMBER", "8")

app = Spaceship::ConnectAPI::App.find(bundle_id)
abort("App Store Connect app not found: #{bundle_id}") unless app

replacement = Spaceship::ConnectAPI::Build.all(
  app_id: app.id,
  platform: platform,
  version: "1.0",
  build_number: replacement_number,
  limit: 10
).first
abort("Replacement build #{replacement_number} is not processed yet") unless replacement
abort("Replacement build #{replacement_number} is #{replacement.processing_state}") unless replacement.processing_state == "VALID"
abort("Replacement build #{replacement_number} has no processed App Store icon") if replacement.icon_asset_token.to_s.empty?

version = app.get_app_store_versions(includes: "build", limit: 20).find do |candidate|
  candidate.platform == platform && candidate.version_string == "1.0"
end
abort("iOS version 1.0 not found") unless version

submission = app.get_in_progress_review_submission(platform: platform)
unless submission
  puts "No in-progress iOS review submission needs withdrawal."
  exit
end

unless submission.state == Spaceship::ConnectAPI::ReviewSubmission::ReviewSubmissionState::WAITING_FOR_REVIEW
  abort("Refusing to cancel iOS submission in state #{submission.state}")
end

selected_build = version.get_build
if selected_build&.version == replacement_number
  puts "iOS build #{replacement_number} is already selected; no withdrawal performed."
  exit
end

canceled = submission.cancel_submission
puts "Withdrawing iOS submission #{submission.id} (build #{selected_build&.version || 'none'}) for valid replacement build #{replacement_number}: #{canceled.state}"
