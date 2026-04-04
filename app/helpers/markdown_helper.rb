module MarkdownHelper
  MARKDOWN_OPTIONS = {
    parse: { smart: true },
    render: { hardbreaks: false, github_pre_lang: true, unsafe: false },
    extension: {
      strikethrough: true,
      table: true,
      tasklist: true,
      autolink: true,
      tagfilter: true
    }
  }.freeze

  def markdown(text)
    return "" if text.blank?

    html = Commonmarker.to_html(text.to_s, options: MARKDOWN_OPTIONS)
    tag.div(html.html_safe, class: "prose")
  end
end
