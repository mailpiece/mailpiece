class CreateSequences < ActiveRecord::Migration[8.2]
  def change
    create_table :sequence_emails, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.string :trigger, limit: 255, null: false
      t.string :subject, limit: 255
      t.string :summary, limit: 300
      t.integer :delay_days, default: 0, null: false
      t.integer :send_hour
      t.string :time_zone, limit: 255
      t.boolean :active, default: false, null: false

      t.timestamps

      t.index %i[ account_id trigger delay_days ]
    end

    create_table :sequence_deliveries, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :email_id, null: false
      t.uuid :subscriber_id, null: false
      t.datetime :deliver_at
      t.datetime :claimed_at
      t.datetime :sent_at
      t.datetime :refused_at
      t.string :message_id, limit: 255

      t.timestamps

      t.index %i[ email_id subscriber_id ], unique: true
      t.index %i[ sent_at refused_at claimed_at deliver_at ], name: "index_sequence_deliveries_on_pending"
      t.index :subscriber_id
    end

    create_table :sequence_runs, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :subscriber_id, null: false
      t.string :trigger, limit: 255, null: false
      t.string :state, limit: 255, default: "in_progress", null: false
      t.datetime :ended_at

      t.timestamps

      t.index %i[ subscriber_id trigger ], unique: true
      t.index %i[ account_id trigger state ]
    end
  end
end
