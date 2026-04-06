module Tools
  class GetDocument < BaseTool
    def name
      "get_document"
    end

    def definition
      {
        name: name,
        description: "Get the full content of a document by ID.",
        inputSchema: {
          type: "object",
          properties: {
            document_id: { type: "integer", description: "ID of the document" }
          },
          required: [ "document_id" ]
        }
      }
    end

    def call(arguments)
      doc = project.documents.find(arguments["document_id"])

      {
        id: doc.id,
        title: doc.title,
        body: doc.body,
        tags: doc.tags.map(&:name),
        created_at: doc.created_at,
        updated_at: doc.updated_at
      }
    end
  end
end
