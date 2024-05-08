# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v1.0.0](https://github.com/ash-project/ash_graphql/compare/v1.0.0-rc.4...v0.28.0) (2024-04-27)

The changelog is being restarted. See `/documentation/1.0-CHANGELOG.md` for previous changelogs.

### Breaking Changes:

- [AshGraphql.Resource] `managed_relationship` arguments automatically get rich types derived for them
- [AshGraphql.Type] No longer automagically derive types. Only types defined in `Ash.Type.NewType` that implement `AshGrahql.Type` will get types derived for them.

### Improvements:

- [AshGraphql.Resolver] Bulk actions are automatically used for create/update/destroy actions. This means far fewer queries made in general.
- [AshGraphql.Type] add `graphql_define_type?/1` callback for graphql types
- [AshGrapqhl.Resource] support generic actions with no return type
