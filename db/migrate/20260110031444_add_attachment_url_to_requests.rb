class AddAttachmentUrlToRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :requests, :attachment_url, :string
  end
end
