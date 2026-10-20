# Development

```bash
bin/setup                  # Gems, DB, schema, demo account
bin/dev                    # Web server at http://app.mailpiece.localhost:3020
bin/rails test             # PARALLEL_WORKERS=1 to serialize
bin/ci                     # Rubocop, audits, Brakeman, tests, seed replant
bin/rails db:seed:replant  # Reseed the demo account (a second db:seed refuses)
bin/jobs                   # Solid Queue
```

Jobs run with `bin/jobs` in a second terminal, or inside the server after
`touch tmp/solid-queue.txt`. Sending, scheduling and confirmation mail need
one of the two: plain `bin/dev` runs no jobs.

The demo account's owner signs in as `mike@example.com`; in development the
code is shown on the screen.

New accounts are open while `MULTI_TENANT=true`, or while there is none. A
signed-in person can always add one from the account menu.

## A newsletter's own domain

An admin types the domain on Settings › Domain, and clears it there. The
domain's DNS and certificate are the owner's: point it at a CDN or proxy that
sends the request on to the app with the `Host` header unchanged. On that host
the newsletter's public pages answer at the root (`/`, `/feed`, a post's page,
`/subscription`, `/link/…`) and its mail links there; sign-in and the admin
screens answer on the app's own address alone, which is `BASE_URL`. Without
`BASE_URL` the app cannot refuse its own host as a domain. Nobody signs in on a
domain: a page that would ask for it is a 404 there.

A proxy that issues certificates on demand asks the app first, at
`/up/host?host=<hostname>` on the app's container: 200 for the app's own host
(only when `BASE_URL` is set) and for a newsletter's domain, 404 for anything
else. It is asked over plain HTTP, which `ASSUME_SSL` (on unless
`DISABLE_SSL=true`) lets through as it does `/up`.

In development the name goes in `config.hosts` first
(`config/environments/development.rb`): with `boletin.localhost` there and on
the demo account, it answers at `http://boletin.localhost:3020`.

## Mail

Mail is configured in ENV alone, in two parts that share nothing. Nothing is
checked at boot: the app starts with none of these set, and a message fails
when it is tried. Every credential is here, and none is kept in the app.

### System mail

Sign-in codes, email-change confirmations and any other mail that is not a
newsletter's own leave over Action Mailer's SMTP, set in production as Fizzy
sets it.

| ENV | |
| --- | --- |
| `SMTP_ADDRESS` | The server. Left out, none of the others is read |
| `SMTP_PORT` | `587`, or `465` with `SMTP_TLS=true`, unless said |
| `SMTP_USERNAME`, `SMTP_PASSWORD` | The install's sign-in |
| `SMTP_AUTHENTICATION`, `SMTP_DOMAIN` | Optional: `plain` unless said, and the HELO domain |
| `SMTP_TLS`, `SMTP_SSL_VERIFY_MODE` | Optional: `true` for a TLS-only port such as 465, and `none` or `peer` |

With `SMTP_ADDRESS` unset production configures nothing and Action Mailer
tries its own default, a server on localhost, so each message fails. In
development this mail never leaves: it is opened in the browser after
`touch tmp/email-dev.txt`, and the sign-in code is shown on the screen either
way.

This mail is sent from `MAILER_FROM_ADDRESS`, and the address inside it is
also where "Need help? Send us an email" writes to: under the signed-out
screens, in the sign-in mail and on an expired confirmation link. With it
unset, as in development, those lines are not shown.

### A newsletter's own mail

Issues, test issues, subscription confirmations and journey emails leave
through a relay or an SMTP server that each newsletter sets on Settings ›
Outgoing mail. Nothing in ENV sets it, and it never uses the
`SMTP_*` settings above: team-facing mail (sign-in, notifications) still goes
over `SMTP_*` from `MAILER_FROM_ADDRESS`.

- **Relay**: the full address each message is POSTed to, used as given, and a
  token sent as `Authorization: Bearer` with every message.
- **SMTP server**: the server and port (587 upgrades to TLS with STARTTLS
  before anything is sent; 465 is TLS from the first byte), and optionally a
  username and password, signed in with `plain`. Left out, the server is asked
  for no sign-in.

The address, server, port and username are edited in place; the token and
the password are set once, never shown again on the screen or in the JSON, and
changed by removing the transport and setting it up again. They are
encrypted with a key derived from `SECRET_KEY_BASE`: rotating it, or
restoring a database under another, makes them unreadable, and the app raises
wherever it reads them. The admin then clears every transport from a console
and each newsletter sets Outgoing mail up again:

```ruby
Account::Sender.update_all(transport: nil, relay_url: nil, relay_token: nil,
  smtp_address: nil, smtp_port: nil, smtp_username: nil, smtp_password: nil)
```

Using one
transport forgets the other's settings, and removing it forgets them all. A
newsletter with no transport, like one with no from address, is not set up and
sends nothing.

The relay is posted each message as JSON, with only the keys that have a
value: `from`, `from_name`, `to`, `cc`, `bcc`, `reply_to`, `reply_to_name`,
`subject`, `html`, `text`, `list_unsubscribe`, `tags` (`issue` on an issue)
and `headers` (the sender's own `X-` headers). An issue's or journey email's
message carries an `Idempotency-Key` header, the delivery's id, and a message
whose fate is unknown is posted again with the same key. **A relay must honour
the key**: it remembers each key it has accepted and answers a repeat as
already done, without sending again. A provider with no key of its own would
otherwise mail the reader twice. The relay answers 2xx when sent, optionally
with `{"message_id": "…"}`; 400, 413 or 422 when refused; 401 or 403 when the
token is wrong; 429 or 503 when nothing was sent. Anything else, or no answer,
is tried again later under the same key.

Nothing marks a subscriber bounced from the mail server's side.

SMTP has no idempotency key, so a delivery whose send was cut short is not
sent again: it stays "unverified", counted on the post, and whether it
arrived is not known.

Only production delivers through a newsletter's transport. There a message
built for a newsletter with no transport all the same raises
`MailDelivery::Unavailable`, so its job retries and then fails, and it never
falls back to the system's SMTP. In development the mail is opened in the
browser after `touch tmp/email-dev.txt`, whatever the transport, and nothing
reaches the relay or SMTP server; the demo newsletter is seeded with a
placeholder relay so it is set up.

`MAIL_DELIVERIES_PER_MINUTE` is the sending rate (default 20;
`config/deploy.yml` sets 30). Deliveries are spaced out to stay under that rate, and a sweep every 15
minutes (`Post::Delivery.deliver_stalled_later`, in `config/recurring.yml`)
queues again the pending rows whose turn passed two hours ago.

## Files

Uploaded files go to the Disk service unless `ACTIVE_STORAGE_SERVICE=s3`,
which both deploy destinations set. An upload not yet attached is read only by
a signed-in user of its account and is swept after two days. HTML, SVG and XML
types are always served as a download.
