require "test_helper"

class Subscriber::ImportTest < ActiveSupport::TestCase
  test "process reads the email column of a CSV" do
    import = import_of "name,email\nFay,Fay@Example.com\nGus,\"gus@example.com\"\n"

    import.process

    assert import.completed?
    assert_equal [ { "email" => "fay@example.com" }, { "email" => "gus@example.com" } ], import.rows
  end

  test "process reads one address per line, without blanks or repeats" do
    import = import_of "fay@example.com\n\ngus@example.com\nFAY@example.com\n", filename: "list.txt", content_type: "text/plain"

    import.process

    assert_equal [ { "email" => "fay@example.com" }, { "email" => "gus@example.com" } ], import.rows
  end

  test "process keeps what is not an address, for the screen to set aside" do
    import = import_of "fay@example.com\nnot an address\n"

    import.process

    assert_equal [ "fay@example.com", "not an address" ], import.rows.pluck("email")
  end

  test "process fails a file with too many addresses" do
    import = import_of((0..Subscriber::Import::ROWS_LIMIT).map { |number| "reader#{number}@example.com" }.join("\n"))

    import.process

    assert import.failed?
    assert import.failed_due_to_too_long?
    assert_nil import.rows
  end

  test "process fails a file that is not text" do
    import = import_of "\xFF\xC3\x28\x00".b, filename: "list.txt", content_type: "text/plain"

    import.process

    assert import.failed?
    assert import.failed_due_to_unreadable?
  end

  test "an import needs a CSV or text file" do
    assert_not Subscriber::Import.new(account: accounts(:davids_account)).valid?

    import = Subscriber::Import.new(account: accounts(:davids_account),
      file: { io: StringIO.new("fay@example.com"), filename: "list.pdf", content_type: "application/pdf" })
    assert_not import.valid?
  end

  test "cleanup removes what was abandoned a day ago" do
    subscriber_imports(:read).update_columns(created_at: 2.days.ago)

    Subscriber::Import.cleanup

    assert_not Subscriber::Import.exists?(subscriber_imports(:read).id)
    assert Subscriber::Import.exists?(subscriber_imports(:other_accounts).id)
  end

  private
    def import_of(text, filename: "list.csv", content_type: "text/csv")
      Subscriber::Import.create! account: accounts(:davids_account), creator: users(:mia),
        file: { io: StringIO.new(text), filename: filename, content_type: content_type }
    end
end
