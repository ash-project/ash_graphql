# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v1.3.2](https://github.com/ash-project/ash_graphql/compare/v1.3.1...v1.3.2) (2024-08-16)




### Bug Fixes:

* match on action in error message properly

### Improvements:

* add schema codegen features & guide

* support new struct types in type generation

* support new struct fields constraint

* Set up GraphQL schema file in the web module namespace (#205)

## [v1.3.1](https://github.com/ash-project/ash_graphql/compare/v1.3.0...v1.3.1) (2024-08-02)




### Bug Fixes:

* use `.has_expression?/0` instead of `function_exported?/3`

* error handling list of atoms (#204)

* error handling list of atoms

## [v1.3.0](https://github.com/ash-project/ash_graphql/compare/v1.2.1...v1.3.0) (2024-08-01)




### Features:

* `Ash.Type.File` compatibility (#202)

### Bug Fixes:

* try to resolve compilation issues w/ `Code.ensure_compiled!`

## [v1.2.1](https://github.com/ash-project/ash_graphql/compare/v1.2.0...v1.2.1) (2024-07-18)




### Bug Fixes:

* upgrade ash dependency for bulk action bug fix

* use checked constraints (#187)

* don't assume `filter` is non-nil for gets

* properly interpolate action in conflict messages

* add resource query to action struct (#178)

### Improvements:

* add extension installation code

* add igniter-backed installer

* add `nullable_fields?` for easily marking fields as nullable

* only define `managed_relationship` mutations when necessary

## [v1.2.0](https://github.com/ash-project/ash_graphql/compare/v1.1.1...v1.2.0) (2024-06-17)




### Features:

* argument_input_types (#176)

* argument_input_types

### Bug Fixes:

* better type handling around empty types

* don't generate empty input objects for embeds

## [v1.1.1](https://github.com/ash-project/ash_graphql/compare/v1.1.0...v1.1.1) (2024-06-02)




### Features:

* relationship pagination (#166)

### Bug Fixes:

* honor read_action for update/destroy mutations

## [v1.1.0](https://github.com/ash-project/ash_graphql/compare/v1.0.1...v1.1.0) (2024-05-24)

### Features:

- [AshGraphql.Domain] support queries/mutations on the domain

## [v1.0.1](https://github.com/ash-project/ash_graphql/compare/v1.0.0...v1.0.1) (2024-05-23)

### Features:

- allow passing custom descriptions to queries and mutations (#138)

### Bug Fixes:

- don't deduplicate argument types by argument name (#162)

- use Ash.EmbeddableType.ShadowDomain (#156)

- accepted attributes don't have to be `public?`

### Improvements:

- deduplicate map types across domains (#164)

- Implement AshGraphql.Error for Ash.Error.Query.ReadActionRequiresActor (#154)

- make mutation result errors list non-nullable (#144)

- make mutation result errors list non-nullable

## [v1.0.0](https://github.com/ash-project/ash_graphql/compare/v1.0.0-rc.4...v0.28.0) (2024-04-27)

The changelog is being restarted. See `/documentation/1.0-CHANGELOG.md` for previous changelogs.

### Breaking Changes:

- [AshGraphql.Resource] `managed_relationship` arguments automatically get rich types derived for them
- [AshGraphql.Type] No longer automagically derive types. Only types defined in `Ash.Type.NewType` that implement `AshGrahql.Type` will get types derived for them.

### Improvements:

- [AshGraphql.Resolver] Bulk actions are automatically used for create/update/destroy actions. This means far fewer queries made in general.
- [AshGraphql.Type] add `graphql_define_type?/1` callback for graphql types
- [AshGrapqhl.Resource] support generic actions with no return type
