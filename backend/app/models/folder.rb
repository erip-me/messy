class Folder < ApplicationRecord
  belongs_to :account
  belongs_to :environment
  belongs_to :parent_folder, class_name: 'Folder', optional: true
  
  has_many :child_folders, class_name: 'Folder', foreign_key: 'parent_folder_id', dependent: :destroy
  has_many :templates, dependent: :nullify
  
  validates :name, presence: true
  validates :name, uniqueness: { scope: [:account_id, :environment_id, :parent_folder_id], conditions: -> { where(is_deleted: false) } }
  
  scope :root_folders, -> { where(parent_folder_id: nil) }
  scope :active, -> { where(is_deleted: false) }
  
  def path
    return [self] if parent_folder.nil?
    parent_folder.path + [self]
  end
  
  def full_name
    path.map(&:name).join(' / ')
  end
end