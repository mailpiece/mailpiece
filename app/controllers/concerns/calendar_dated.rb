module CalendarDated
  extend ActiveSupport::Concern

  private
    def date(name = :date)
      Date.iso8601(params[name])
    rescue ArgumentError, TypeError
      raise ActiveRecord::RecordNotFound
    end
end
