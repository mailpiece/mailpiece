module RichTextHelper
  def post_snippets_prompt
    content_tag "lexxy-prompt", "", trigger: "/", src: prompts_snippets_path, name: "snippet", "insert-editable-text": true
  end

  # Sanitized so nothing stored gets out of the template it is served in.
  def snippet_editable_html(snippet)
    if content = snippet.content.body
      sanitize_action_text_content content.render_attachments(&:to_editor_attachment)
    end
  end

  def audience_editor_box(audience)
    tag.aside tag.p(tag.br), data: { audience: audience.name }
  end

  # CSS holds no text of its own, so the name over each kind of box reaches the stylesheet from here.
  def post_audience_labels_style
    Post::Audience.all.map { |audience| "--audience-#{audience.medium}-label: #{audience.label.to_json}" }.join("; ")
  end
end
