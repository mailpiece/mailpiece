# Restoring the databases from R2

Litestream backs up `production.sqlite3`, `production_queue.sqlite3`,
`production_cable.sqlite3` and `production_cache.sqlite3` to R2 and keeps fifteen
days of history.

Uploaded files live in the files bucket (`mailpiece-production`,
`mailpiece-staging`) and need no restore: a new server reads the logos and the
images in posts from where they already are. The bucket itself has no backup
and no history, so a file deleted from it is gone, and a database restored to
an earlier time can point at files purged since.

Run everything from the repo root. Use `-d staging` and `script/restore staging`
for staging. The script and these steps have not been run for Mailpiece yet,
on a running server or a brand new one.

## Restore

```bash
kamal server bootstrap -d production   # a new server only
kamal deploy -d production
script/restore production
```

- The old server must stay off, or two machines write to the same bucket.
- Deploy first: the script runs inside the app's image and volume.
- Never `kamal setup` to bring a server back. It boots Litestream beside the
  empty databases a new app creates, and they are backed up on top of the real
  history. It is only for the first deploy, when there is no history.

The script stops the app and Litestream, moves the current databases to
`/rails/storage/aside`, shows the backups and asks for a `y`, restores the
four, and starts the app. Litestream stays stopped.

Then log in and check the data. The script prints the commands for both
outcomes: start Litestream and delete `aside`, or put the old databases back.
Do not start Litestream on data you have not checked.

The same script rehearses a restore on a running server, or after a
`kamal remove` and a `kamal deploy`.

## Looking

```bash
kamal backups -d production         # every backup file, with time and size
kamal storage -d production         # what is in the storage volume
kamal restore-check -d production   # latest backup into restored.sqlite3, beside the live one
```

Delete `restored.sqlite3` afterwards; a second run refuses to overwrite it.

## If the restore brings back an empty database

The newest backup is an empty database on top of the real one. It happens
after a `kamal setup`, or when the files are deleted under a running app. Done
on a staging install on 2026-10-06.

In `kamal backups`, find where the real activity ends and the empty database
begins: a pause, then one large transaction. Pick a UTC time between the two.

```bash
kamal app stop -d production
kamal accessory stop litestream -d production

kamal accessory exec litestream -d production \
  "restore -dry-run -timestamp 2026-10-06T17:15:00Z -o /rails/storage/check.sqlite3 /rails/storage/production.sqlite3"
```

If the plan ends at the last real transaction:

```bash
for db in production production_queue production_cable production_cache; do
  kamal accessory exec litestream -d production \
    "restore -force -integrity-check quick -timestamp 2026-10-06T17:15:00Z /rails/storage/$db.sqlite3"
done

kamal app exec -d production "bash -c 'rm -rf /rails/storage/.production*.sqlite3-litestream'"
kamal app start -d production
```

Check the data, start Litestream, and confirm with `kamal restore-check`.

## If something goes wrong

- **The script stops before doing anything.** `/rails/storage/aside` is left
  from an earlier restore. Look with `kamal storage`, then delete it:
  `kamal app exec -d production "bash -c 'rm -rf /rails/storage/aside'"`.
  It is the only copy of the old databases.
- **The databases were deleted from the server.** Do not restart or redeploy.
  Run the script straight away and read the backup list before answering `y`.
- **`no matching backup files available`.** Litestream never ran beside the
  live databases. `kamal accessory logs litestream -d production` shows it.
- **A permission error on restore.** `/rails/storage` must be owned by uid
  1000, which it is when the app's image created the volume on deploy.
- **`AccessDenied`.** `R2_HOST` in 1Password must be the bare host, and the
  Litestream token needs Object Read & Write on the Litestream bucket.

Litestream's docs: https://litestream.io/reference/restore/
