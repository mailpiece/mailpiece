json.partial! "posts/revisions/revision", revision: @revision
json.title @revision.title
json.body @revision.body.to_plain_text
json.body_html @revision.body.to_s
