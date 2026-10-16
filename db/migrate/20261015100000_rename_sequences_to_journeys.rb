class RenameSequencesToJourneys < ActiveRecord::Migration[8.2]
  def change
    rename_table :sequence_emails, :journey_emails
    rename_table :sequence_deliveries, :journey_deliveries
    rename_table :sequence_runs, :journey_runs

    rename_index :journey_deliveries, :index_sequence_deliveries_on_pending, :index_journey_deliveries_on_pending
  end
end
