// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "initializers"
import "controllers"
import * as Lexxy from "lexxy"
import AudienceExtension from "editor/audience_extension"
import VideoThumbnailExtension from "editor/video_thumbnail_extension"
import "@rails/actiontext"

import "lib/action_pack/passkey"

Lexxy.configure({ global: { extensions: [ AudienceExtension, VideoThumbnailExtension ] } })
