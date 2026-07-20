# frozen_string_literal: true

require "json"
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
    build_number: ENV.fetch("IOS_BUILD_NUMBER", "9")
  },
  {
    bundle_id: "me.ph7.SucceedAI",
    platform: Spaceship::ConnectAPI::Platform::MAC_OS,
    build_number: ENV.fetch("MAC_BUILD_NUMBER", "9")
  }
]

report = targets.map do |target|
  app = Spaceship::ConnectAPI::App.find(target[:bundle_id])
  abort("App Store Connect app not found: #{target[:bundle_id]}") unless app

  uploads = Spaceship::ConnectAPI::BuildUpload.all(
    app_id: app.id,
    version: "1.0",
    build_number: target[:build_number]
  )
  builds = Spaceship::ConnectAPI::Build.all(
    app_id: app.id,
    platform: target[:platform],
    version: "1.0",
    build_number: target[:build_number],
    limit: 10
  )

  {
    bundle_id: target[:bundle_id],
    platform: target[:platform],
    build_number: target[:build_number],
    uploads: uploads.map do |upload|
      {
        state: upload.state,
        platform: upload.platform,
        uploaded_date: upload.uploaded_date
      }
    end,
    builds: builds.map do |build|
      {
        id: build.id,
        processing_state: build.processing_state,
        icon_present: !build.icon_asset_token.to_s.empty?,
        encryption_exempt: build.uses_non_exempt_encryption == false,
        uploaded_date: build.uploaded_date
      }
    end
  }
end

puts JSON.pretty_generate(report)
