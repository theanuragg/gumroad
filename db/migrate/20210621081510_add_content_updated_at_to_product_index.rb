# frozen_string_literal: true

class AddContentUpdatedAtToProductIndex < ActiveRecord::Migration[6.1]
  def up
    EsClient.indices.put_mapping(
      index: Link.index_name,
      body: {
        properties: {
          content_updated_at: { type: "date" },
        }
      }
    )
  end
end
