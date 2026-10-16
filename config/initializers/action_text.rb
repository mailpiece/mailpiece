module ActionText
  module Extensions
    module RichText
      extend ActiveSupport::Concern

      included do
        # This overrides the default :embeds association!
        has_many_attached :embeds do |attachable|
          ::Attachments::VARIANTS.each do |variant_name, variant_options|
            attachable.variant variant_name, **variant_options, process: :immediately
          end
        end
      end

      def accessible_to?(user)
        record.try(:accessible_to?, user) || record.try(:publicly_accessible?)
      end

      def publicly_accessible?
        record.try(:publicly_accessible?)
      end
    end
  end
end

ActiveSupport.on_load(:action_text_rich_text) do
  include ActionText::Extensions::RichText
end

# What marks a post's picture for the lightbox is written by the attachment's partial, and the
# sanitizer that runs over the rendered text would drop it. Added to whatever is allowed so far.
# A box kept for one audience is an <aside> naming it, which the editor and a post's history draw as written.
ActiveSupport.on_load(:action_text_content) do
  helper = Class.new.include(ActionText::ContentHelper).new
  ActionText::ContentHelper.allowed_attributes = helper.sanitizer_allowed_attributes + %w[ data-lightbox-target data-audience ]
  ActionText::ContentHelper.allowed_tags = helper.sanitizer_allowed_tags + %w[ aside ]
end
