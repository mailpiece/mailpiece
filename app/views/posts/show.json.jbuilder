json.partial! "posts/post", post: @post
json.brought_subscribers_count @post.brought_subscribers.count
json.liked_count @post.ratings.liked.count
json.disliked_count @post.ratings.disliked.count
