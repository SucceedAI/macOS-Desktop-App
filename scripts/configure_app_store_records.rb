# frozen_string_literal: true

require "spaceship"

KEY_ID = ENV.fetch("ASC_KEY_ID", "QLSK2QDQ67")
ISSUER_ID = ENV.fetch("ASC_ISSUER_ID", "0937aa2d-d63f-411e-928e-0ec39732c589")
KEY_PATH = File.expand_path(ENV.fetch("ASC_KEY_PATH", "~/.appstoreconnect/AuthKey_QLSK2QDQ67.p8"))
CONTACT_SOURCE_APP_ID = "6743055043"

TARGETS = [
  {
    bundle_id: "me.ph7.Succeed-AI",
    platform: Spaceship::ConnectAPI::Platform::IOS,
    notes_path: "fastlane/review-information-ios/notes.txt"
  },
  {
    bundle_id: "me.ph7.SucceedAI",
    platform: Spaceship::ConnectAPI::Platform::MAC_OS,
    notes_path: "fastlane/review-information-mac/notes.txt"
  }
].freeze

RATING_ATTRIBUTES = {
  alcohol_tobacco_or_drug_use_or_references: "NONE",
  contests: "NONE",
  gambling_simulated: "NONE",
  guns_or_other_weapons: "NONE",
  horror_or_fear_themes: "NONE",
  mature_or_suggestive_themes: "NONE",
  medical_or_treatment_information: "NONE",
  profanity_or_crude_humor: "NONE",
  sexual_content_graphic_and_nudity: "NONE",
  sexual_content_or_nudity: "NONE",
  violence_cartoon_or_fantasy: "NONE",
  violence_realistic_prolonged_graphic_or_sadistic: "NONE",
  violence_realistic: "NONE",
  advertising: false,
  age_assurance: false,
  gambling: false,
  health_or_wellness_topics: false,
  loot_box: false,
  messaging_and_chat: false,
  parental_controls: false,
  unrestricted_web_access: false,
  user_generated_content: false
}.freeze

token = Spaceship::ConnectAPI::Token.create(
  key_id: KEY_ID,
  issuer_id: ISSUER_ID,
  filepath: KEY_PATH
)
Spaceship::ConnectAPI.token = token

source_app = Spaceship::ConnectAPI::App.all.find { |app| app.id == CONTACT_SOURCE_APP_ID }
abort("Could not find an existing App Review contact source") unless source_app

source_contact = source_app.get_app_store_versions(limit: 20).filter_map do |version|
  detail = version.fetch_app_store_review_detail
  fields = [detail&.contact_first_name, detail&.contact_last_name, detail&.contact_email, detail&.contact_phone]
  detail if fields.all? { |value| value && !value.empty? }
rescue Spaceship::UnexpectedResponse, RuntimeError
  nil
end.first
abort("No complete App Review contact exists on the account") unless source_contact

territory_ids = nil

TARGETS.each do |target|
  app = Spaceship::ConnectAPI::App.find(target[:bundle_id])
  abort("Could not find #{target[:bundle_id]}") unless app

  app.update(attributes: {
    contentRightsDeclaration: Spaceship::ConnectAPI::App::ContentRightsDeclaration::DOES_NOT_USE_THIRD_PARTY_CONTENT
  })

  app_info = app.fetch_edit_app_info || app.fetch_latest_app_info
  abort("Could not find editable app info for #{target[:bundle_id]}") unless app_info
  app_info.fetch_age_rating_declaration.update(attributes: RATING_ATTRIBUTES)

  begin
    Spaceship::ConnectAPI::AppDataUsage
      .all(app_id: app.id, includes: "category,grouping,purpose,dataProtection", limit: 500)
      .each(&:delete!)
    Spaceship::ConnectAPI::AppDataUsage.create(
      app_id: app.id,
      app_data_usage_protection_id: Spaceship::ConnectAPI::AppDataUsageDataProtection::ID::DATA_NOT_COLLECTED
    )
    publish_state = Spaceship::ConnectAPI::AppDataUsagesPublishState.get(app_id: app.id)
    publish_state.publish! unless publish_state.published
  rescue Spaceship::UnexpectedResponse => error
    warn "App privacy requires the App Store Connect web form for #{target[:bundle_id]}: #{error.message.lines.first.strip}"
  end

  version = app.get_edit_app_store_version(platform: target[:platform])
  abort("Could not find editable version for #{target[:bundle_id]}") unless version
  review_attributes = {
    contact_first_name: source_contact.contact_first_name,
    contact_last_name: source_contact.contact_last_name,
    contact_email: source_contact.contact_email,
    contact_phone: source_contact.contact_phone,
    demo_account_required: false,
    notes: File.read(target[:notes_path]).strip
  }
  review_detail = begin
    version.fetch_app_store_review_detail
  rescue Spaceship::UnexpectedResponse, RuntimeError
    nil
  end
  if review_detail
    review_detail.update(attributes: review_attributes)
  else
    version.create_app_store_review_detail(attributes: review_attributes)
  end

  begin
    priced_app = Spaceship::ConnectAPI::App.get(app_id: app.id, includes: "prices")
    if priced_app.prices&.any?
      app.update(app_price_tier_id: "0")
    else
      territory_ids ||= Spaceship::ConnectAPI::Territory.all.map(&:id)
      app.update(
        app_price_tier_id: "0",
        territory_ids: territory_ids
      )
    end
  rescue Spaceship::UnexpectedResponse => error
    warn "Pricing requires the App Store Connect web form for #{target[:bundle_id]}: #{error.message.lines.first.strip}"
  end

  puts "Configured #{target[:bundle_id]} for submission"
end
