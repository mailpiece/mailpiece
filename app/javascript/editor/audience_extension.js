import * as Lexxy from "lexxy"
import { AudienceNode, $ensureLineIn, $isAudienceNode, $unwrapAudience } from "editor/audience_node"

const {
  ParagraphNode,
  $getSelection,
  $isRangeSelection,
  $isElementNode,
  $findMatchingParent,
  $createParagraphNode,
  KEY_ENTER_COMMAND,
  KEY_BACKSPACE_COMMAND,
  KEY_ARROW_DOWN_COMMAND,
  KEY_ARROW_UP_COMMAND,
  COMMAND_PRIORITY_LOW
} = Lexxy.Lexical

// Teaches the editor the box kept for one audience: the node that makes it survive a save, where a box or a
// snippet picked from the menu lands, and the keys that get the writer back out of a box.
export default class AudienceExtension extends Lexxy.Extension {
  get enabled() {
    return this.editorElement.supportsRichText
  }

  // The sanitizer's allowed tags come from the registered nodes; only the attribute needs saying.
  get allowedElements() {
    return [ { tag: "aside", attributes: [ "data-audience" ] } ]
  }

  get lexicalExtension() {
    return this.defineExtension({
      name: "mailpiece/audiences",
      nodes: [ AudienceNode ],
      register(editor) {
        const teardowns = [
          editor.registerNodeTransform(AudienceNode, $ensureLineIn),
          editor.registerNodeTransform(ParagraphNode, $liftBlocksOutOf),
          editor.registerCommand(KEY_ENTER_COMMAND, $escapeOnEnter, COMMAND_PRIORITY_LOW),
          editor.registerCommand(KEY_BACKSPACE_COMMAND, $unwrapOnBackspace, COMMAND_PRIORITY_LOW),
          editor.registerCommand(KEY_ARROW_DOWN_COMMAND, $escapeDownwards, COMMAND_PRIORITY_LOW),
          editor.registerCommand(KEY_ARROW_UP_COMMAND, $escapeUpwards, COMMAND_PRIORITY_LOW)
        ]

        return () => teardowns.forEach((teardown) => teardown())
      }
    })
  }
}

// The menu puts what it pastes inside the paragraph the slash was typed in, which is right for a word and
// wrong for a box, a list or the paragraphs of a snippet. Those are moved to follow the paragraph, in order,
// and the writer goes on inside the box, or after the last thing pasted.
function $liftBlocksOutOf(paragraph) {
  const blocks = paragraph.getChildren().filter((child) => $isElementNode(child) && !child.isInline())
  if (blocks.length === 0) return

  let previous = paragraph
  blocks.forEach((block) => {
    previous.insertAfter(block)
    previous = block
  })

  if (paragraph.getTextContent().trim() === "") paragraph.remove()

  const box = blocks.find($isAudienceNode)
  if (box) {
    $ensureLineIn(box)
    box.selectStart()
  } else {
    previous.selectEnd()
  }
}

// The block the caret sits in, when it is a direct child of a box.
function $currentBlockInAudience() {
  const selection = $getSelection()
  if (!$isRangeSelection(selection) || !selection.isCollapsed()) return null

  return $findMatchingParent(selection.anchor.getNode(), (node) => $isAudienceNode(node.getParent()))
}

// Enter on an empty last line leaves the box, as it leaves a list or a quote.
function $escapeOnEnter(event) {
  const block = $currentBlockInAudience()
  if (!block || block.getNextSibling() || block.getTextContentSize() > 0) return false

  const audience = block.getParent()
  const paragraph = $createParagraphNode()

  audience.insertAfter(paragraph)
  block.remove()
  if (audience.isEmpty()) audience.remove()
  paragraph.select()

  event?.preventDefault()
  return true
}

// Backspace at the very start of a box takes the box away and keeps what was written in it.
function $unwrapOnBackspace(event) {
  const block = $currentBlockInAudience()
  const selection = $getSelection()
  if (!block || block.getPreviousSibling() || selection.anchor.offset !== 0) return false
  if (selection.anchor.getNode() !== block && selection.anchor.getNode() !== block.getFirstDescendant()) return false

  $unwrapAudience(block.getParent())
  block.selectStart()

  event?.preventDefault()
  return true
}

// The arrows need help only at the very start or end of the text, where there is no block to move into.
function $escapeDownwards() {
  return $escapeVertically("getNextSibling", "insertAfter")
}

function $escapeUpwards() {
  return $escapeVertically("getPreviousSibling", "insertBefore")
}

function $escapeVertically(sibling, insert) {
  const block = $currentBlockInAudience()
  if (!block || block[sibling]()) return false

  const audience = block.getParent()
  if (audience[sibling]()) return false

  const paragraph = $createParagraphNode()
  audience[insert](paragraph)
  paragraph.select()

  return true
}
