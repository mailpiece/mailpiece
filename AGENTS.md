# Mailpiece

Mailpiece is a multi-tenant newsletter app: one account is one newsletter,
with public posts and a subscriber list, and each post sent is mailed to the
list through a relay or over SMTP.

These instructions are defaults with reasons, not law: when the code in front
of you disagrees, take the better path and flag the conflict. Invariants (data
loss, security, a person's choice not to be mailed, an issue mailed once) are
surfaced, not overridden. Fizzy is the reference for how things are built;
where these instructions and Fizzy disagree, Fizzy is probably right, so flag
it and ask. Attack your own diff before calling it done.

## Multi-tenancy is URL-based

Accounts get a decimal `external_account_id` URL prefix, may also answer at a
`handle`, and may have a `domain` of their own. Three extractors run in this
order, pinned by a test: `AccountSlug::Extractor` (as in Fizzy),
`AccountHandle::Extractor`, `AccountDomain::Extractor`. The first two set
`Current.account` and move the slug from `PATH_INFO` to `SCRIPT_NAME`, so
routes are written unprefixed and route helpers that assume a bare root will
mislead you. The third reads `HTTP_HOST`, never a forwarded host, and puts the
path back, so on a domain the account comes from the host alone.

A domain answers a reader's pages and nothing else. `config/routes.rb` holds
what any host answers, and `config/routes/app.rb` the app's own screens, which
a domain refuses. A link that crosses between the two is a `_url` built with
`Account#reader_url_options`, never a `_path`. Nobody signs in on a domain:
what would ask for it answers 404 there, and a domain sets no cookie.

Domain records are reached through `Current.account`; sessions, signup,
`/my/identity` and `/admin` declare `disallow_account_scope`. A global
`Identity` (email) can hold `User`s on several accounts.

## UUID primary keys

All tables use UUIDv7 keys stored as `blob(16)`, base36-encoded to 25
characters. Id order is creation order, and fixture ids sort older than any
runtime record. `insert_all` and `upsert_all` need an explicit `id:`. A blank
string is stored as sixteen zero bytes, not NULL, so never let a form submit a
blank uuid.

## Authorization

`User::Role` is `owner admin member system`, and `admin?` is true of an owner.
Configuration is `ensure_admin`, and
`test/integration/admin_authorization_test.rb` pins which routes are, so every
new route goes on one of its lists. Staff (`Identity#staff?`, the identity
that made the first account) see Mission Control at `/admin/jobs`.

While no account exists the sign-in code is shown on screen in every
environment. That is the install path, since the first account is made before
mail is set up. It is deliberate: never "fix" it.

## A post is published once and sent once

`publish` stamps `published_at` once and `deliver` sets `sent_at` once;
calling either again does nothing. `unpublish` makes a post never mailed a
draft again and leaves an issue already mailed sent, by email only: it is
never a draft and never mailed twice. A post is deleted for good with its
revisions, deliveries and links, so the links in an issue already mailed stop
answering. A post is found by its `code`, never by its slug, and its two
routes are the last in the file.

Nothing renders `post.body` to a reader: every renderer reads
`body_on_the_web` or `body_in_email` (`Post::Readable`), which drop the boxes
the editor's `/onlyweb` and `/onlyemail` keep for the other audience.

## Only the person undoes an unsubscribe or a bounce

A subscriber's status is read from four dates, in this order: `bounced_at`,
`deactivated_at`, `unsubscribed_at`, `confirmed_at`, and only an `active` one
is mailed. `Subscriber.add` never brings back someone who unsubscribed or
bounced, and `deactivate` and `activate` reverse neither. The person undoes
either by subscribing again and confirming from the link. An admin can delete
a subscriber for good, and the address is then new again.

Bounced is set by an admin, or by a provider through the API
(`POST /subscribers/bounces.json`), and never undone but by the person;
nothing counts bounces. A subscriber's `token` never
changes and is for unsubscribe links only. The public form writes no row while
the sender is incomplete.

## Public pages carry no session

`Public::BaseController` pages are cached publicly for 30 seconds, so never
render anything there that depends on who is signed in. A file is as public as
its record says (`publicly_accessible?`), and a post's files are served even
for a draft, because a mail client loads a test email's images with no
session. The CSRF check is skipped in two places: the one-click unsubscribe
and the embedded subscription form. The embedded form returns to the account's `subscription_return_url`, never to one from the request.

## Two kinds of mail

System mail (sign-in codes, email changes) leaves over Action Mailer's SMTP,
set from `SMTP_*` as in Fizzy. A newsletter's own mail is the mailers that
include `Mailers::SentBySender`: it leaves as the account's `Account::Sender`
through the transport `MailTransport` reads from `NEWSLETTER_MAIL_*`, and
never borrows `SMTP_*` or the system address. Nothing is checked at boot: with
no transport, production raises `MailDelivery::Unavailable` for each message.

`Post::Delivery` is one row per post and subscriber. The relay is posted the
row's id as `Idempotency-Key` and never claims it, so a row may be tried any
number of times: an issue mailed once rests on the relay honouring the key,
answering a repeat as already done without sending again. SMTP has no key, so
the row is claimed (`claimed_at`) in one UPDATE before the mail goes, and a
claim left standing is never sent again: it reads "unverified".
`raise_delivery_errors` stays true, or a failed send is recorded
as sent. Only the person's link or an admin confirming one unconfirmed
person starts the confirmation journey, never adding or importing.

## English and Spanish

Every word goes through `t()`, in `config/locales/en.yml` and `es.yml`;
`test/lib/locales_test.rb` fails when one lacks a key. The language is the
account's (`accounts.locale`, nil reads as English), and a newsletter's own
mail is built inside `in_account_locale`, so a job writes it in that language.

## Interface

Sign in, signup, join, passkeys and access tokens are built the way Fizzy
builds them. A stylesheet
or Stimulus controller with a Fizzy name is Fizzy's file byte for byte, and
our rules go in a file beside it (`site-corners.css` squares the corners).
Three are changed in place by decision: `auto_save_controller.js`,
`lightbox_controller.js` with `lightbox.css`, and `pagination_controller.js`,
which gains `data-delay`. Icons come only from Fizzy.

Lists page as they are scrolled; the calendar's agenda has short windows, so
its links are pressed (`calendar_more_link`). A field's hint is written
Fizzy's way: `<br>` then `<p class="margin-none txt-x-small txt-subtle">`
inside the label.

## Schema and config

There are no foreign keys (except Active Storage's) and no check constraints.
Migrations are always new files. Configuration comes from ENV; credentials are
not used. `MAILER_FROM_ADDRESS` falls back to support@mailpiece.dev, as Fizzy's
does to its own, so a fresh install boots before its mail is set.

## Development

```bash
bin/setup                  # Gems, DB, schema, demo account
bin/dev                    # Web server at http://app.mailpiece.localhost:3020
bin/rails test             # PARALLEL_WORKERS=1 to serialize
bin/ci                     # Rubocop, audits, Brakeman, tests, seed replant
bin/rails db:seed:replant  # Reseed the demo account (a second db:seed refuses)
bin/jobs                   # Solid Queue
```

Plain `bin/dev` runs no jobs: use `bin/jobs`, or `touch tmp/solid-queue.txt`.
The demo owner is `mike@example.com`. The mail ENV is in `docs/development.md`.

## Coding style

Before editing or reviewing code, read STYLE.md.