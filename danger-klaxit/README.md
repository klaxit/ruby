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



[//]: #--------------------------------------------------- (external references)
[git-rebase]: https://git-scm.com/docs/git-rebase#Documentation/git-rebase.txt---autostash
[doc-danger-ci]: https://danger.systems/guides/getting_started.html#setting-up-danger-to-run-on-your-ci
