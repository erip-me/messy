class CreateDatabase < ActiveRecord::Migration[7.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false

      t.timestamps
    end

    create_table :users do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false, index: true
      t.datetime :last_login_at

      t.timestamps
    end

    create_table :environments do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name
      t.string :api_key, null: false
      t.boolean :allow_email, null: false, default: false
      t.boolean :allow_sms, null: false, default: false
      t.boolean :allow_whatsapp, null: false, default: false
      t.boolean :allow_mobile_push, null: false, default: false
      t.boolean :allow_web_push, null: false, default: false
      t.boolean :is_deleted, null: false, default: false

      t.timestamps
    end

    create_table :rules do |t|
      t.references :account, null: false, foreign_key: true
      t.references :environment, null: false, foreign_key: true
      t.string :type, null: false, index: true
      t.string :condition, null: false
      t.jsonb :tags, default: [], null: false
      t.integer :scope, null: false, default: 0
      t.integer :outcome, null: false, default: 0
      t.boolean :is_deleted, null: false, default: false

      t.timestamps
    end

    create_table :templates do |t|
      t.references :account, null: false, foreign_key: true
      t.references :environment, null: false, foreign_key: true
      t.string :name, null: false
      t.string :trigger
      t.string :subject
      t.text :body, null: false
      t.boolean :is_deleted, null: false, default: false

      t.timestamps
    end

    create_table :messages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :environment, null: false, foreign_key: true
      t.references :template, null: true, foreign_key: true
      t.string :type, null: false, index: true
      t.string :trigger
      t.string :to, null: false
      t.string :cc
      t.string :bcc
      t.string :subject
      t.text :body, null: false
      t.jsonb :tags, default: [], null: false
      t.integer :scope, null: false, default: 0
      t.integer :status, default: 0, null: false
      t.datetime :sent_at
      t.boolean :is_deleted, null: false, default: false

      t.timestamps
    end

    create_table :integrations do |t|
      t.references :account, null: false, foreign_key: true
      t.string :type
      t.string :vendor
      t.integer :kind, default: 0, null: false
      t.jsonb :config, default: [], null: false

      t.timestamps
    end

    create_table :deliveries do |t|
      t.references :message, null: false, foreign_key: true
      t.references :integration, null: false, foreign_key: true
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error

      t.timestamps
    end
  end
end
