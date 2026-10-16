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

New accounts are open while `MULTI_TENANT=true`, or while there is none.

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

Issues, test issues and subscription confirmations leave through a relay or
over SMTP, as `NEWSLETTER_MAIL_TRANSPORT` says. They never use the `SMTP_*`
settings above.

| ENV | |
| --- | --- |
| `NEWSLETTER_MAIL_TRANSPORT` | `relay` or `smtp` |
| `NEWSLETTER_MAIL_RELAY_URL` | Relay: the full address each message is POSTed to, used as given |
| `NEWSLETTER_MAIL_RELAY_TOKEN` | Relay: sent as `Authorization: Bearer` with every message |
| `NEWSLETTER_MAIL_SMTP_ADDRESS`, `_SMTP_PORT` | SMTP: the server, shared by every newsletter |
| `NEWSLETTER_MAIL_SMTP_USERNAME`, `_SMTP_PASSWORD` | SMTP, optional: the install's own sign-in. Left out, the SMTP server is asked for none |
| `NEWSLETTER_MAIL_SMTP_AUTHENTICATION`, `_SMTP_DOMAIN`, `_SMTP_TLS`, `_SMTP_SSL_VERIFY_MODE` | SMTP, optional: `plain` unless said (and only with a username), the HELO domain, `true` for a TLS-only port such as 465 (STARTTLS is required otherwise), and `none` or `peer` |

The relay is posted each message as JSON, with only the keys that have a
value: `from`, `from_name`, `to`, `cc`, `bcc`, `reply_to`, `reply_to_name`,
`subject`, `html`, `text`, `list_unsubscribe`, `tags` (`issue` on an issue)
`headers` (the sender's own `X-` headers) and `attachments` (each
`{ name, content_type, content, cid }`, the content base64 and the `cid`, in
angle brackets, only on a picture the HTML shows as `cid:`). An issue's or journey email's
message carries an `Idempotency-Key` header, the delivery's id, and a message
whose fate is unknown is posted again with the same key. **A relay must honour
the key**: it remembers each key it has accepted and answers a repeat as
already done, without sending again. A provider with no key of its own would
otherwise mail the reader twice. The relay answers 2xx when sent, optionally
with `{"message_id": "…"}`; 400, 413 or 422 when refused; 401 or 403 when the
token is wrong; 429 or 503 when nothing was sent. Anything else, or no answer,
is tried again later under the same key.

Settings holds only who a newsletter writes as: a from name, a from address
and a reply-to, on its Sending page. Nothing marks a subscriber bounced from
the mail server's side.

SMTP has no idempotency key, so a delivery whose send was cut short is not
sent again: it stays "unverified", counted on the post, and whether it
arrived is not known.

In production a transport left unset, or set to a name nobody knows, raises
`MailDelivery::Unavailable` for each message, so its jobs retry and then fail.
In development it sends nowhere: the mail is opened in the browser after
`touch tmp/email-dev.txt`. Set `NEWSLETTER_MAIL_*` to send it for real. Tests
ignore all of these.

`OFFLINE=true` is for an install no reader can reach, such as one on a laptop
that reaches only its SMTP server or relay. Issues and journey emails then point
nowhere in the app: uploaded pictures, a video's preview and a YouTube video's
copied thumbnail go inside the message, 600 pixels wide, other files go as
attachments, links lead where they were written, and there is no rating and no
"View on the web". `List-Unsubscribe` is a `mailto:` to the reply-to address,
or else the from address, and the footer asks for a reply. The relay is posted
the pictures and files as `attachments`, so a relay that refuses a file's name
or type refuses the message. Subscription confirmations still link to the app.

`MAIL_DELIVERIES_PER_MINUTE` is the sending rate (default 20;
`config/deploy.yml` sets 30). Deliveries are spaced out to stay under that rate, and a sweep every 15
minutes (`Post::Delivery.deliver_stalled_later`, in `config/recurring.yml`)
queues again the pending rows whose turn passed two hours ago.

## Files

Uploaded files go to the Disk service unless `ACTIVE_STORAGE_SERVICE=s3`,
which both deploy destinations set. An upload not yet attached is read only by
a signed-in user of its account and is swept after two days. HTML, SVG and XML
types are always served as a download.
