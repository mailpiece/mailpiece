import * as Lexxy from "lexxy"

const {
  DecoratorNode,
  $applyNodeReplacement,
  $createParagraphNode,
  $getNodeByKey,
  $getSelection,
  $isElementNode,
  $isRangeSelection,
  $isParagraphNode
} = Lexxy.Lexical

// Post::Video::ADDRESS in JavaScript: the two change together.
const YOUTUBE_ADDRESS = /^https?:\/\/(?:(?:www\.|m\.)?youtube\.com\/(?:watch\?(?:[^#]*&)?v=|shorts\/)|youtu\.be\/)([A-Za-z0-9_-]{11})(?:[\/?&#].*)?$/

// The events of a field that Lexical would otherwise take for the text around the picture.
const FIELD_EVENTS = [ "keydown", "keyup", "keypress", "beforeinput", "input", "compositionstart", "compositionend", "paste", "cut", "copy", "click" ]

// A video is stored as a link alone in its paragraph, and its caption is the link's text, which is the
// address until the writer says more:
//
//   <p><a href="https://youtu.be/dQw4w9WgXcQ">https://youtu.be/dQw4w9WgXcQ</a></p>
//
// The page, the feed and the email draw it as the video's thumbnail over that text. This node shows the
// picture while writing, with the text in a field under it, and stores nothing else: createDOM draws them,
// exportDOM hands the paragraph and link back. Modelled on Pagecord's embed.
export class VideoThumbnailNode extends DecoratorNode {
  __url
  __text

  static getType() {
    return "video-thumbnail"
  }

  static clone(node) {
    return new VideoThumbnailNode(node.__url, node.__text, node.__key)
  }

  // Lexical's own link node claims every <a> at priority 1, so a video's link has to outbid it; null for
  // any other link leaves it the handling it had.
  static importDOM() {
    return {
      a: (element) => isVideoElement(element) ? { conversion: convertVideoElement, priority: 3 } : null
    }
  }

  static importJSON(serializedNode) {
    return $createVideoThumbnailNode(serializedNode.url, serializedNode.text).updateFromJSON(serializedNode)
  }

  constructor(url, text = url, key) {
    super(key)
    this.__url = url
    this.__text = text
  }

  isInline() {
    return false
  }

  // A picture and no link: a click selects it, as it selects an attachment.
  createDOM(config, editor) {
    const image = document.createElement("img")
    image.src = `https://img.youtube.com/vi/${videoIdIn(this.__url)}/hqdefault.jpg`
    image.alt = ""

    const picture = document.createElement("div")
    picture.className = "video-thumbnail__picture"
    picture.appendChild(image)

    const caption = document.createElement("figcaption")
    caption.className = "attachment__caption"
    caption.appendChild(this.#createField(editor))

    const element = document.createElement("figure")
    element.className = "video-thumbnail"
    element.append(picture, caption)

    return element
  }

  // The field is written to only when it says something else, which is an undo: while the writer types it
  // already holds the text, and setting it again would move the caret.
  updateDOM(prevNode, element) {
    const field = element.querySelector("textarea")
    if (field.value !== this.__text) field.value = this.__text

    return false
  }

  exportDOM() {
    const link = document.createElement("a")
    link.setAttribute("href", this.__url)
    link.textContent = this.__text.replace(/\s+/g, " ").trim() || this.__url

    const paragraph = document.createElement("p")
    paragraph.appendChild(link)

    return { element: paragraph }
  }

  exportJSON() {
    return { ...super.exportJSON(), url: this.__url, text: this.__text }
  }

  getTextContent() {
    return this.__url
  }

  decorate() {
    return null
  }

  setText(text) {
    this.getWritable().__text = text
  }

  // One line, as a link's text is. Its events stop here, so a key pressed, a paste or a click in the field
  // is the field's own and never the editor's.
  #createField(editor) {
    const key = this.getKey()
    const field = document.createElement("textarea")
    field.rows = 1
    field.value = this.__text
    field.placeholder = this.__url

    FIELD_EVENTS.forEach((type) => field.addEventListener(type, (event) => event.stopPropagation()))

    field.addEventListener("input", () => {
      editor.update(() => $getNodeByKey(key)?.setText(field.value))
    })

    field.addEventListener("keydown", (event) => {
      if (event.key === "Enter" && !event.isComposing) {
        event.preventDefault()
        field.blur()
        editor.getRootElement()?.focus({ preventScroll: true })
        editor.update(() => {
          const node = $getNodeByKey(key)
          if (node) $moveCaretAfter(node)
        })
      }
    })

    return field
  }
}

export function $createVideoThumbnailNode(url, text) {
  return $applyNodeReplacement(new VideoThumbnailNode(url, text))
}

export function $isVideoThumbnailNode(node) {
  return node instanceof VideoThumbnailNode
}

// A pasted link arrives as a node in a live document, where importDOM never runs, so the paragraph is where
// it is caught; it is also where the node importDOM made is lifted out of the paragraph it was read in.
//
// A paragraph still inside another one is what the menu pasted and $liftBlocksOutOf has yet to move: it moves
// paragraphs and would leave a bare picture behind, so the paragraph is left whole until it has been moved.
export function $pictureVideoParagraph(paragraph) {
  if ($isParagraphNode(paragraph.getParent())) return

  const children = paragraph.getChildren()
  if (children.length !== 1) return

  const thumbnail = $thumbnailFor(children[0])
  if (!thumbnail) return

  const caretWasInside = $caretIsIn(paragraph)
  paragraph.replace(thumbnail)
  if (caretWasInside) $moveCaretAfter(thumbnail)
}

function $thumbnailFor(node) {
  if ($isVideoThumbnailNode(node)) {
    return node
  } else if (isVideoLinkNode(node)) {
    return $createVideoThumbnailNode(node.getURL(), node.getTextContent())
  }
}

function $caretIsIn(paragraph) {
  const selection = $getSelection()
  if (!$isRangeSelection(selection)) return false

  const anchor = selection.anchor.getNode()
  return anchor.is(paragraph) || paragraph.isParentOf(anchor)
}

// A picture holds no text, so the caret that was in its paragraph points at a node that is gone, and Lexical
// answers by dropping the selection. It is given somewhere to land, which at the end, or before another
// picture, means a new paragraph.
function $moveCaretAfter(thumbnail) {
  const next = thumbnail.getNextSibling()

  if ($isElementNode(next)) {
    next.selectStart()
  } else {
    const paragraph = $createParagraphNode()
    thumbnail.insertAfter(paragraph)
    paragraph.selectEnd()
  }
}

function videoIdIn(url) {
  return url.match(YOUTUBE_ADDRESS)?.[1]
}

// Post::Video.from's rule: a link to a video that is alone in its paragraph, whatever its text. A link that
// carries more than exportDOM writes back (a target, a title, elements inside it) stays a link while writing,
// since claiming it would rewrite it; a rel is let through and lost on the next save, which changes nothing
// for a reader.
function isVideoElement(element) {
  return videoIdIn(element.getAttribute("href") ?? "") &&
    [ ...element.attributes ].every((attribute) => [ "href", "rel" ].includes(attribute.name)) &&
    element.childElementCount === 0 &&
    element.parentElement?.nodeName === "P" &&
    element.parentElement.childNodes.length === 1
}

function convertVideoElement(element) {
  return { node: $createVideoThumbnailNode(element.getAttribute("href"), element.textContent) }
}

// The same question as isVideoElement, asked of a link that is already a node.
function isVideoLinkNode(node) {
  return node.getType() === "link" &&
    videoIdIn(node.getURL()) &&
    !node.getTarget() && !node.getTitle()
}
