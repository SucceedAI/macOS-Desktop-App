# frozen_string_literal: true

require "spaceship"

Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
  key_id: ENV.fetch("ASC_KEY_ID", "QLSK2QDQ67"),
  issuer_id: ENV.fetch("ASC_ISSUER_ID", "0937aa2d-d63f-411e-928e-0ec39732c589"),
  filepath: File.expand_path(ENV.fetch("ASC_KEY_PATH", "~/.appstoreconnect/AuthKey_QLSK2QDQ67.p8"))
)

app = Spaceship::ConnectAPI::App.find("me.ph7.Succeed-AI")
abort("iOS app not found") unless app

version = app.get_app_store_versions(limit: 20).find do |candidate|
  candidate.platform == Spaceship::ConnectAPI::Platform::IOS && candidate.version_string == "1.0"
end
abort("iOS version 1.0 not found") unless version

detail = version.fetch_app_store_review_detail
abort("iOS App Review information not found") unless detail

contact = [detail.contact_first_name, detail.contact_last_name, detail.contact_email, detail.contact_phone]
abort("iOS App Review contact is incomplete") unless contact.all? { |value| !value.to_s.strip.empty? }

notes = File.read("fastlane/review-information-ios/notes.txt").strip
abort("iOS App Review notes file is empty") if notes.empty?

detail.update(attributes: { notes: notes, demo_account_required: false })
puts "Updated iOS App Review notes while preserving the complete contact information."
