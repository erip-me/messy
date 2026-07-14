class ConversationAssignment < ApplicationRecord
  belongs_to :conversation
  belongs_to :assigned_by, class_name: "User", optional: true
  belongs_to :assigned_to, class_name: "User"
end
