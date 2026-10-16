json.partial! "subscribers/subscriber", subscriber: @subscriber
json.deliveries @page.records, partial: "subscribers/delivery", as: :delivery
