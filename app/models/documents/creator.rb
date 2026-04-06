module Documents
  class Creator
    def self.call(author:, project:, title:, body:, tag_names: [])
      document = project.documents.create!(
        title: title,
        body: body,
        author: author
      )

      tag_names.each do |name|
        tag = project.document_tags.find_or_create_by!(name: name.strip.downcase)
        document.document_taggings.find_or_create_by!(document_tag: tag)
      end

      document
    end
  end
end
