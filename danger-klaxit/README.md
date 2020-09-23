# danger-klaxit

## Usage

You can directly import this plugin as a gem from GitHub using:

```ruby
gem "danger-klaxit", github: "klaxit/ruby", glob: "danger-klaxit/*.gemspec"
```

Methods and attributes from this plugin are available in your `Dangerfile`
under the `klaxit` namespace. For starters, you could use:

```ruby
# Dangerfile
klaxit.common
```

Dont forget to also [add danger to your CI][doc-danger-ci]!

## Available methods

- **klaxit.warn_rubocop** — will write inline rubocop comments
- **klaxit.fail_for_bad_commits** — will fail if a commit contain `/wip/i` or a
  git autosquash keyword, see [git rebase documentation][git-rebase]. Or even if
  there are two commits with the same name.
- **klaxit.warn_for_public_methods_without_specs** — will write inline comment
  for a new public method that has no spec.
- **klaxit.warn_for_bad_order_in_config** — will write a diff comment if repo's
  modified `config/config.yml` is not ordered
- **klaxit.run_brakeman_scanner** — will write a markdown report if there is a
  brakeman issue. This should only be used in rails or active_record projects.
- **klaxit.warn_for_not_updated_structure_sql** -- will write inline comments
  if there is migrations but structure.sql is not updated or the migrations
  timestamps are not added



[//]: #--------------------------------------------------- (external references)
[git-rebase]: https://git-scm.com/docs/git-rebase#Documentation/git-rebase.txt---autostash
[doc-danger-ci]: https://danger.systems/guides/getting_started.html#setting-up-danger-to-run-on-your-ci
