class CreateDeviceLogins < ActiveRecord::Migration[7.2]
  def change
    create_table :device_logins do |t|
      t.string :code, null: false
      t.string :state, null: false, default: 'pending'
      t.integer :user_id
      t.string :device_digest, null: false
      t.text :user_agent
      t.string :ip
      t.string :ip_bucket
      t.text :return_to
      t.timestamptz :approved_at
      t.timestamptz :expires_at, null: false
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :device_logins, [:code, :state]
    add_index :device_logins, :device_digest
    add_index :device_logins, [:ip_bucket, :created_at]

    create_table :device_login_attempts do |t|
      t.integer :user_id, null: false
      t.boolean :ok, null: false, default: false
      t.timestamptz :created_at, null: false
    end
    add_index :device_login_attempts, [:user_id, :created_at]
  end
end
