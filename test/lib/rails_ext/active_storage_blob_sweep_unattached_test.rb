require "test_helper"

class ActiveStorageBlobSweepUnattachedTest < ActiveSupport::TestCase
  test "sweep_unattached purges unattached blobs older than two days" do
    stale = create_blob
    stale.update! created_at: 3.days.ago

    fresh = create_blob

    attached = create_blob
    posts(:draft).update! body: "<p>#{ActionText::Attachment.from_attachable(attached).to_html}</p>"
    attached.update! created_at: 3.days.ago

    perform_enqueued_jobs only: ActiveStorage::PurgeJob do
      ActiveStorage::Blob.sweep_unattached
    end

    assert_not ActiveStorage::Blob.exists?(stale.id)
    assert ActiveStorage::Blob.exists?(fresh.id)
    assert ActiveStorage::Blob.exists?(attached.id)
  end

  private
    def create_blob
      ActiveStorage::Blob.create_and_upload! io: StringIO.new("notes"), filename: "notes.txt", content_type: "text/plain"
    end
end
