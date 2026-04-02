module Tools
  class SearchDocuments < BaseTool
    def name
      "search_documents"
    end

    def definition
      {
        name: name,
        description: "Search the company document library by title or tag.",
        inputSchema: {
          type: "object",
          properties: {
            query: { type: "string", description: "Search documents by title (substring match)" },
            tag: { type: "string", description: "Filter documents by tag name" }
          }
        }
      }
    end

    def call(arguments)
      scope = company.documents.includes(:tags)
      scope = scope.search_by_title(arguments["query"]) if arguments["query"].present?
      scope = scope.tagged_with(arguments["tag"]) if arguments["tag"].present?

      documents = scope.order(updated_at: :desc).limit(25).map do |doc|
        {
          id: doc.id,
          title: doc.title,
          tags: doc.tags.map(&:name),
          updated_at: doc.updated_at
        }
      end

      { documents: documents, count: documents.size }
    end
  end
end
