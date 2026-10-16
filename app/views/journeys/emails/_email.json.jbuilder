json.(email, :id, :subject, :summary)
json.body email.body.to_plain_text
json.body_html email.body.to_s
json.(email, :delay_days, :send_hour, :time_zone, :active)
json.created_at email.created_at.utc
json.updated_at email.updated_at.utc
json.url journey_email_url(email.journey, email, format: :json)
