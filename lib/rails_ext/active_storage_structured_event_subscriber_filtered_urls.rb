require "active_storage/structured_event_subscriber"

# Active Storage emits each URL it generates as a debug event that skips payload filtering, and with
# Rails.event in debug mode (config/application.rb) every event subscriber, the production JSON log among
# them, got a presigned storage URL with its X-Amz-Signature: a working link to the file until it expires.
# Emit the URL with its query filtered by filter_parameters, pair by pair, as the text log line filters it.
module ActiveStorageStructuredEventSubscriberFilteredUrls
  def service_url(event)
    emit_debug_event("active_storage.service_url",
      key: event.payload[:key],
      url: filtered_url(event.payload[:url]),
      duration_ms: event.duration.round(2),
    )
  end

  private
    def filtered_url(url)
      before_fragment, fragment_separator, fragment = url.to_s.partition("#")
      location, query_separator, query = before_fragment.partition("?")
      "#{location}#{query_separator}#{filtered_query(query)}#{fragment_separator}#{fragment}"
    end

    def filtered_query(query)
      query.split(/([&;])/).map do |part|
        if part.include?("=")
          name, value = part.split("=", 2)
          parameter_filter.filter(name => value).first.join("=")
        else
          part
        end
      end.join
    end

    def parameter_filter
      @parameter_filter ||= ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    end
end

ActiveStorage::StructuredEventSubscriber.prepend ActiveStorageStructuredEventSubscriberFilteredUrls
