unless Rails.env.development?
  puts "WARN: Seeding is just for development!"
else
  tenant_id = ActiveRecord::FixtureSet.identify "Mailpiece Demo"

  if Account.exists?(external_account_id: tenant_id)
    abort "Mailpiece Demo is already seeded. Run bin/rails db:seed:replant to start over."
  end

  identity = Identity.find_or_create_by!(email_address: "mike@example.com", staff: true)

  account = Account.create_with_owner(
    account: {
      external_account_id: tenant_id,
      name: "Mailpiece Demo",
      description: "Short notes on keeping contractor paperwork in order. One post every couple of weeks, written for the people who check the files."
    },
    owner: {
      name: "Mike Torres",
      identity: identity
    }
  )

  owner = account.users.owner.sole

  account.posts.create! creator: owner, published_at: 6.weeks.ago, sent_at: 6.weeks.ago,
    title: "What to ask a contractor for before the first day",
    body: <<~HTML
      <p>Before a contractor sets foot on site it pays to have four papers in hand. Asking for them after the first day means chasing every expiry date.</p>
      <h2>The minimum</h2>
      <ul>
        <li>Proof of tax registration</li>
        <li>The workers' compensation policy, with the list of people it covers</li>
        <li>The mandatory life insurance</li>
        <li>Last month's payroll tax return, with its proof of payment</li>
      </ul>
      <p>That is enough to open the file. The rest depends on the job: a cleaning company and a crew working at height do not need the same papers.</p>
    HTML

  account.posts.create! creator: owner, published_at: 3.weeks.ago, sent_at: 3.weeks.ago,
    title: "Three papers that expire every month",
    body: <<~HTML
      <p>Some documents are asked for once, and others have to be asked for again every month. These three are the ones that most often go out of date.</p>
      <ol>
        <li><strong>The payroll tax return.</strong> It expires with each period. Without the proof of payment it is not enough.</li>
        <li><strong>The certificate of coverage.</strong> Many insurers issue it for thirty days.</li>
        <li><strong>Signed payslips.</strong> One for each person who comes on site.</li>
      </ol>
      <blockquote>An expired paper in the file is a person who should not be inside.</blockquote>
      <p>The simplest thing is to set one day of the month to ask for all of them together, and to tell each contractor a week before.</p>
    HTML

  account.posts.create! creator: owner, published_at: 4.days.ago,
    title: "How to put together a contractor's file",
    body: <<~HTML
      <p>A tidy file is reviewed in five minutes. An untidy one is never reviewed.</p>
      <h2>Three folders</h2>
      <p>Separate what belongs <strong>to the company</strong>, what belongs <strong>to each person</strong> and what belongs <strong>to each vehicle or machine</strong>. Each paper goes in one folder only.</p>
      <h2>One date per paper</h2>
      <p>Beside each document, write down until when it is valid. If it has no expiry, write down when you received it.</p>
      <p>In the next post: what to do when a contractor subcontracts.</p>
    HTML

  account.posts.create! creator: owner, published_at: 2.days.ago, visibility: "unlisted",
    title: "A note for the people at the March workshop",
    body: <<~HTML
      <p>Thank you for coming. This page is not in the archive: it is only reachable by the link we gave you.</p>
      <p>The checklist we filled in together is the one from the first post, with the dates of your own contractors.</p>
    HTML

  account.posts.create! creator: owner, published_at: 1.week.ago, sent_at: 1.week.ago, visibility: "email_only",
    title: "For subscribers only: the checklist as a spreadsheet",
    body: <<~HTML
      <p>This one has no web page. It went to the list by email and can only be read there.</p>
      <p>Reply to this email and we will send you the spreadsheet.</p>
    HTML

  account.posts.create! creator: owner,
    title: "When the contractor subcontracts",
    body: <<~HTML
      <p>Draft. The company that hires also answers for the subcontractor, so the file has to follow the chain.</p>
      <ul>
        <li>Ask for the contract between the two companies</li>
        <li>Open a file of its own for the subcontractor</li>
      </ul>
    HTML

  account.posts.create!(creator: owner,
    title: "A calendar for the year's renewals",
    body: <<~HTML
      <p>Most of a contractor's papers come up for renewal on dates you can know in advance. Put them on one calendar in January and the year has no surprises.</p>
      <ul>
        <li>Insurance policies, on their anniversary</li>
        <li>Medical checks, once a year for each person</li>
        <li>Vehicle inspections, by plate number</li>
      </ul>
    HTML
  ).schedule at: 3.days.from_now.change(hour: 9), deliver: true

  %w[
    martha.quinn@southernbuilders.example
    purchasing@coaststeel.example
    office@riveraerectors.example
    george.bennett@electrosouth.example
    hr@valleytransport.example
    safety@andespainting.example
  ].each { |email| account.subscribers.add email }

  %w[
    safety@riveraerectors.example
    lucy.ferris@cleanworks.example
  ].each { |email| account.subscribers.create! email: email, confirmation_sent_at: Time.current }

  %w[
    paul.sosa@northscaffolding.example
    works@pampaconcrete.example
  ].each { |email| account.subscribers.add(email).unsubscribe }

  %w[
    info@riverwelding.example
    old.contact@mendozacranes.example
  ].each { |email| account.subscribers.add(email).bounce }

  account.subscribers.add("former.client@deltaroofing.example").deactivate

  account.posts.where.not(sent_at: nil).each do |post|
    account.subscribers.active.each do |subscriber|
      post.deliveries.create! subscriber: subscriber, deliver_at: post.sent_at, sent_at: post.sent_at
    end
  end

  account.create_sender! from_name: "Mailpiece Demo", from_address: "demo@mailpiece.example", reply_to_address: "editor@mailpiece.example"
end
