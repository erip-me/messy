class AddEmailScoreToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :email_score, :integer
    add_column :customers, :email_score_checked_at, :datetime
  end
end
