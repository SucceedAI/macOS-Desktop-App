# frozen_string_literal: true

require "spaceship"

Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
  key_id: ENV.fetch("ASC_KEY_ID", "QLSK2QDQ67"),
  issuer_id: ENV.fetch("ASC_ISSUER_ID", "0937aa2d-d63f-411e-928e-0ec39732c589"),
  filepath: File.expand_path(ENV.fetch("ASC_KEY_PATH", "~/.appstoreconnect/AuthKey_QLSK2QDQ67.p8"))
)

targets = [
  ["me.ph7.Succeed-AI", Spaceship::ConnectAPI::Platform::IOS],
  ["me.ph7.SucceedAI", Spaceship::ConnectAPI::Platform::MAC_OS]
]

targets.each do |bundle_id, platform|
  app = Spaceship::ConnectAPI::App.find(bundle_id)
  abort("App Store Connect app not found: #{bundle_id}") unless app

  in_progress = app.get_in_progress_review_submission(platform: platform)
  if in_progress
    puts "#{bundle_id} is already submitted: #{in_progress.state}"
    next
  end

  version = app.get_app_store_versions(includes: "build", limit: 20).find do |candidate|
    candidate.platform == platform && candidate.version_string == "1.0"
  end
  abort("Version 1.0 not found for #{bundle_id}") unless version

  build = version.get_build
  abort("No build is selected for #{bundle_id}") unless build
  abort("Selected build is not valid for #{bundle_id}: #{build.processing_state}") unless build.processing_state == "VALID"
  abort("Selected build has no processed App Store icon for #{bundle_id}") if build.icon_asset_token.to_s.empty?

  review_detail = version.fetch_app_store_review_detail
  contact_fields = [
    review_detail&.contact_first_name,
    review_detail&.contact_last_name,
    review_detail&.contact_phone,
    review_detail&.contact_email
  ]
  abort("App Review contact is incomplete for #{bundle_id}") unless contact_fields.all? { |value| !value.to_s.strip.empty? }
  abort("App Review notes are missing for #{bundle_id}") if review_detail.notes.to_s.strip.empty?

  submission = app.get_ready_review_submission(platform: platform, includes: "items")
  unless submission
    submission = app.create_review_submission(platform: platform)
    submission.add_app_store_version_to_review_items(app_store_version_id: version.id)
  end

  submitted = submission.submit_for_review
  abort("Unexpected review state for #{bundle_id}: #{submitted.state}") unless submitted.state == "WAITING_FOR_REVIEW"
  puts "Submitted #{bundle_id} version 1.0 build #{build.version}: #{submitted.state}"
end
