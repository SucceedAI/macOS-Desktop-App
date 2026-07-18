# frozen_string_literal: true

require "json"
require "spaceship"

key_path = File.expand_path(ENV.fetch("ASC_KEY_PATH", "~/.appstoreconnect/AuthKey_QLSK2QDQ67.p8"))
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
  key_id: ENV.fetch("ASC_KEY_ID", "QLSK2QDQ67"),
  issuer_id: ENV.fetch("ASC_ISSUER_ID", "0937aa2d-d63f-411e-928e-0ec39732c589"),
  filepath: key_path
)

targets = [
  ["me.ph7.Succeed-AI", Spaceship::ConnectAPI::Platform::IOS],
  ["me.ph7.SucceedAI", Spaceship::ConnectAPI::Platform::MAC_OS]
]

report = targets.map do |bundle_id, platform|
  app = Spaceship::ConnectAPI::App.find(bundle_id)
  abort("App Store Connect app not found: #{bundle_id}") unless app

  version = app.get_app_store_versions(includes: "build", limit: 20).find do |candidate|
    candidate.platform == platform && candidate.version_string == "1.0"
  end
  abort("Version 1.0 not found for #{bundle_id} (#{platform})") unless version

  build = begin
    version.get_build
  rescue Spaceship::UnexpectedResponse, RuntimeError
    nil
  end

  localizations = version.get_app_store_version_localizations.map do |localization|
    screenshot_sets = localization.get_app_screenshot_sets(includes: "appScreenshots").map do |set|
      screenshots = set.app_screenshots || []
      {
        display_type: set.screenshot_display_type,
        count: screenshots.length,
        complete: screenshots.count(&:complete?),
        files: screenshots.map(&:file_name)
      }
    end

    {
      locale: localization.locale,
      description_present: !localization.description.to_s.strip.empty?,
      keywords_present: !localization.keywords.to_s.strip.empty?,
      support_url_present: !localization.support_url.to_s.strip.empty?,
      marketing_url_present: !localization.marketing_url.to_s.strip.empty?,
      promotional_text_present: !localization.promotional_text.to_s.strip.empty?,
      whats_new_present: !localization.whats_new.to_s.strip.empty?,
      screenshot_sets: screenshot_sets
    }
  end

  review_detail = begin
    version.fetch_app_store_review_detail
  rescue Spaceship::UnexpectedResponse, RuntimeError
    nil
  end

  privacy = begin
    Spaceship::ConnectAPI::AppDataUsagesPublishState.get(app_id: app.id)
  rescue Spaceship::UnexpectedResponse, RuntimeError
    nil
  end

  review_submissions = begin
    app.get_review_submissions(filter: { platform: platform }, includes: "items").map do |submission|
      { id: submission.id, state: submission.state, item_count: (submission.items || []).length }
    end
  rescue Spaceship::UnexpectedResponse, RuntimeError
    []
  end

  {
    bundle_id: bundle_id,
    app_id: app.id,
    platform: platform,
    version_id: version.id,
    version: version.version_string,
    app_store_state: version.app_store_state,
    app_version_state: version.app_version_state,
    release_type: version.release_type,
    build: build && {
      id: build.id,
      number: build.version,
      processing_state: build.processing_state,
      icon_present: !build.icon_asset_token.to_s.empty?,
      encryption_exempt: build.uses_non_exempt_encryption == false
    },
    copyright_present: !version.copyright.to_s.strip.empty?,
    review_information: review_detail && {
      contact_complete: [
        review_detail.contact_first_name,
        review_detail.contact_last_name,
        review_detail.contact_phone,
        review_detail.contact_email
      ].all? { |value| !value.to_s.strip.empty? },
      notes_present: !review_detail.notes.to_s.strip.empty?,
      demo_account_required: review_detail.demo_account_required
    },
    privacy_published: privacy&.published,
    localizations: localizations,
    review_submissions: review_submissions
  }
end

puts JSON.pretty_generate(report)
