class AddFeedbackToPendingHires < ActiveRecord::Migration[8.1]
  def change
    add_column :pending_hires, :feedback, :text
  end
end
