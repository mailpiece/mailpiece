# Backing up and restoring the database

`script/admin/prepare-backup` copies the main database with SQLite's online
backup, so the app keeps running, to `storage/backups/production.sqlite3` in
the storage volume:

```bash
kamal app exec "script/admin/prepare-backup"
```

Copy that file off the server, for example with `docker cp` from the app's
container and `scp`. Only the main database is backed up: the queue, cable and
cache databases are made empty when the app starts.

Uploaded files live in the files bucket (`mailpiece-production`,
`mailpiece-staging`) and need no restore: a new server reads the logos and the
images in posts from where they already are. The bucket itself has no backup
and no history, so a file deleted from it is gone, and a database restored to
an earlier time can point at files purged since.

## Restore

Deploy first, put the copy back at `storage/backups/production.sqlite3` in the
storage volume, then:

```bash
kamal app stop
kamal app exec "bash -c 'mkdir /rails/storage/aside && mv /rails/storage/production*.sqlite3* /rails/storage/aside/ && cp /rails/storage/backups/production.sqlite3 /rails/storage/production.sqlite3'"
kamal app start
```

The old server must stay off, or two machines send the same mail. Starting the
app makes the other three databases again. Log in and check the data, then
delete `/rails/storage/aside`, or move its files back to undo the restore.

The server must have the same `SECRET_KEY_BASE` the database was written
under: each newsletter's relay token or SMTP password is encrypted with a key
derived from it. Under another, Outgoing mail raises until the transports are
cleared from a console and set up again (see "A newsletter's own mail" in
development.md).

## What a restore loses

Everything written since the backup was taken, and the jobs waiting at the
time. Issue and journey deliveries are rows, so the sweeps every 15 minutes
queue them again once their turn is two hours past: they arrive late, not
never. A confirmation email whose job is lost is lost for good, because the
subscriber's row already counted it as sent.

Everyone mailed after the backup shows as unsent again. Over SMTP they are
mailed a second time; the relay takes each delivery once by its
`Idempotency-Key` and sends nothing new. A delivery over SMTP caught between
its claim and its stamp stays unverified and is not sent again.
