class ApplicationJob < ActiveJob::Base
  prepend AccountTenanted
end
