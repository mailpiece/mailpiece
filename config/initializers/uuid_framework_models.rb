# Inject account associations into Rails framework models
Rails.application.config.to_prepare do
  ActionMailbox::InboundEmail.belongs_to :account, default: -> { Current.account }

  ActionText::RichText.belongs_to :account, default: -> { record.account }

  ActiveStorage::Attachment.belongs_to :account, default: -> { record.account }

  ActiveStorage::Blob.belongs_to :account, default: -> { Current.account }

  ActiveStorage::VariantRecord.belongs_to :account, default: -> { blob.account }
end
