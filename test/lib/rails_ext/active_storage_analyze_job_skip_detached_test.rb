require "test_helper"

class ActiveStorageAnalyzeJobSkipDetachedTest < ActiveSupport::TestCase
  test "skips analysis when blob has no attachments" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("x" * 1024), filename: "orphan.txt", content_type: "text/plain"
    )

    blob.expects(:analyze).never

    ActiveStorage::AnalyzeJob.perform_now(blob)
  end

  test "performs analysis when blob has attachments" do
    account = accounts(:davids_account)
    account.avatar.attach io: file_fixture("moon.jpg").open, filename: "test.jpg", content_type: "image/jpeg"
    blob = account.avatar.blob

    blob.expects(:analyze).once

    ActiveStorage::AnalyzeJob.perform_now(blob)
  end
end
