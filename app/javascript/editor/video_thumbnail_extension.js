import * as Lexxy from "lexxy"
import { $isAudienceNode } from "editor/audience_node"
import { VideoThumbnailNode, $isVideoThumbnailNode, $pictureVideoParagraph } from "editor/video_thumbnail_node"

const {
  ParagraphNode,
  $getSelection,
  $isNodeSelection,
  $createParagraphNode,
  KEY_ARROW_DOWN_COMMAND,
  KEY_ARROW_UP_COMMAND,
  COMMAND_PRIORITY_NORMAL
} = Lexxy.Lexical

// Shows a video's thumbnail in the editor as the page and the email will. Nothing about the stored post
// changes: the node exports the paragraph and link it was made from, so this is a preview only.
export default class VideoThumbnailExtension extends Lexxy.Extension {
  get enabled() {
    return this.editorElement.supportsRichText
  }

  // No allowedElements: the picture is only ever in the editor's own DOM, never in what is saved.
  get lexicalExtension() {
    return this.defineExtension({
      name: "mailpiece/video-thumbnails",
      nodes: [ VideoThumbnailNode ],
      register(editor) {
        const teardowns = [
          editor.registerNodeTransform(ParagraphNode, $pictureVideoParagraph),
          editor.registerCommand(KEY_ARROW_DOWN_COMMAND, $lineBelowInBox, COMMAND_PRIORITY_NORMAL),
          editor.registerCommand(KEY_ARROW_UP_COMMAND, $lineAboveInBox, COMMAND_PRIORITY_NORMAL)
        ]

        return () => teardowns.forEach((teardown) => teardown())
      }
    })
  }
}

// A picture that opens or closes a box has no line beside it to move the caret to, so the arrow makes one.
function $lineBelowInBox(event) {
  return $lineBesideInBox("getNextSibling", "insertAfter", event)
}

function $lineAboveInBox(event) {
  return $lineBesideInBox("getPreviousSibling", "insertBefore", event)
}

function $lineBesideInBox(sibling, insert, event) {
  const selection = $getSelection()
  const thumbnail = $isNodeSelection(selection) && selection.getNodes()[0]
  if (!$isVideoThumbnailNode(thumbnail) || !$isAudienceNode(thumbnail.getParent()) || thumbnail[sibling]()) return false

  const paragraph = $createParagraphNode()
  thumbnail[insert](paragraph)
  paragraph.select()

  event?.preventDefault()
  return true
}
