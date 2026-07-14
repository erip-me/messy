class MakeCampaignSubjectAndFromEmailNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :campaigns, :subject, true
    change_column_null :campaigns, :from_email, true
  end
end
