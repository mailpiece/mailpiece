json.posts @posts, partial: "posts/post", as: :post
json.subscribers @page.records, partial: "subscribers/subscriber", as: :subscriber
