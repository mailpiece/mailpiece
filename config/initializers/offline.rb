Rails.application.configure do
  config.x.offline = ENV["OFFLINE"] == "true"
end
