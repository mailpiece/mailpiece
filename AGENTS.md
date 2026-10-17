# Mailpiece

Mailpiece is a multi-tenant newsletter app: one account is one newsletter, its
posts published on the web and mailed to its subscribers.

These instructions are defaults with reasons, not law — when the code in
front of you disagrees, take the better path and flag the conflict; invariants
(data loss, security, a person's choice not to be mailed, an issue mailed
once) are surfaced, not overridden. Fizzy is the reference for how things are
built; where these instructions and Fizzy disagree, Fizzy is probably right,
so flag it and ask. Attack your own diff before calling it done.

## Multi-tenancy is URL-based

Accounts get a decimal `external_account_id` URL prefix, may answer at a
`handle`, and may have a `domain`. Three extractors run in this order, pinned
by a test: `AccountSlug::Extractor`, `AccountHandle::Extractor`,
`AccountDomain::Extractor`. The first two set `Current.account` and move the
slug from `PATH_INFO` to `SCRIPT_NAME`, so route helpers that assume a bare
root will mislead you. The third reads `HTTP_HOST`, never a forwarded host.
Domain records are account-scoped; identity, session, and authentication
records are the global exceptions. A global `Identity` (email-based) can hold
`Users` in multiple accounts, so an email address is not a single account
membership.

A domain answers a reader's pages and nothing else: `config/routes.rb` is what
any host answers, `config/routes/app.rb` the app's screens. A link between the
two is a `_url` built with `Account#reader_url_options`, never a `_path`.
Nobody signs in on a domain, and a domain sets no cookie.

## UUID primary keys

All tables use UUIDv7 keys, base36-encoded to 25 characters. Fixture UUIDs
sort older than any runtime record, so don't "fix" ordering by comparing
insertion order to id order. A blank string is stored as sixteen zero bytes,
not NULL, so never let a form submit a blank uuid.

## The sign-in code is shown while no account exists

That is the install path, since the first account is made before mail is set
up. It is deliberate in every environment: never "fix" it.

## Public pages carry no session

`Public::BaseController` pages are cached publicly for 30 seconds, so render
nothing there that depends on who is signed in. Nothing renders `post.body` to
a reader: go through `body_on_the_web` or `body_in_email` (`Post::Readable`).
A post's files are served even for a draft, since a mail client loads a test
email's images with no session. The CSRF check is skipped on the one-click
unsubscribe and the embedded subscription form.

## Two kinds of mail

System mail leaves over Action Mailer's `SMTP_*`, as in Fizzy. A newsletter's
own mail (mailers including `Mailers::SentBySender`) leaves through
`MailTransport` from the relay or SMTP server set on its Sending page and
never borrows `SMTP_*`.

The relay is posted a `Post::Delivery` id as `Idempotency-Key` and may be
retried; SMTP has no key, so the row is claimed in one UPDATE first and a
standing claim is never sent again. `raise_delivery_errors` stays true, or a
failed send is recorded as sent.

## Interface

Every word goes through `t()`, in `config/locales/en.yml` and `es.yml`. A
stylesheet or Stimulus controller with a Fizzy name is Fizzy's file byte for
byte; our rules go in a file beside it. Three are changed in place by
decision: `auto_save_controller.js`, `lightbox_controller.js` with
`lightbox.css`, and `pagination_controller.js`.

## Schema, config and jobs

There are no foreign keys (except Active Storage's) and no check constraints.
Configuration comes from ENV; credentials are not used. Plain `bin/dev` runs
no jobs: use `bin/jobs`, or `touch tmp/solid-queue.txt`.

## Code we write

Comment only where a reader would otherwise make a mistake; the why goes in
the commit message. Between two defensible designs, take the one with less new
code. Never patch a library's internals.

## Coding style

Before editing or reviewing code, read STYLE.md.
