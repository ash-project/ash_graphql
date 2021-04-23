# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v0.16.0](https://github.com/ash-project/ash_graphql/compare/v0.15.10...v0.16.0) (2021-04-23)




### Features:

* derived input objects for managed_relationships

### Bug Fixes:

* various input fixes (sorts)

### Improvements:

* support new style enums

* support `ash_context` key

## [v0.15.10](https://github.com/ash-project/ash_graphql/compare/v0.15.9...v0.15.10) (2021-04-19)




### Improvements:

* support `read_action` config for updates and destroys

* support `identity: false` for udpates and destroys

## [v0.15.9](https://github.com/ash-project/ash_graphql/compare/v0.15.8...v0.15.9) (2021-04-19)




### Bug Fixes:

* project down to multiple levels for `result` types

## [v0.15.8](https://github.com/ash-project/ash_graphql/compare/v0.15.7...v0.15.8) (2021-04-18)




### Bug Fixes:

* set actor when building changeset

## [v0.15.7](https://github.com/ash-project/ash_graphql/compare/v0.15.6...v0.15.7) (2021-04-16)




### Bug Fixes:

* proper not found errors

## [v0.15.6](https://github.com/ash-project/ash_graphql/compare/v0.15.5...v0.15.6) (2021-04-16)




### Bug Fixes:

* correctly select fields to clear

* don't clear fields on `nil` result

## [v0.15.5](https://github.com/ash-project/ash_graphql/compare/v0.15.4...v0.15.5) (2021-04-15)




### Bug Fixes:

* load fields required for relationship

## [v0.15.4](https://github.com/ash-project/ash_graphql/compare/v0.15.3...v0.15.4) (2021-04-13)




### Bug Fixes:

* detect all embeddable types in arguments and nested

* detect enums in embeddable types and arguments

* error messages for `InvalidArgument`

* store refs in graphql blueprint to fix error messages

### Improvements:

* log on unrenderable error messages

* update to latest ash

## [v0.15.3](https://github.com/ash-project/ash_graphql/compare/v0.15.2...v0.15.3) (2021-04-09)




### Bug Fixes:

* fix graphql subselections for pagination

* fix authorization docs

## [v0.15.2](https://github.com/ash-project/ash_graphql/compare/v0.15.1...v0.15.2) (2021-04-06)




### Bug Fixes:

* don't show non-predicate operators in filters

## [v0.15.1](https://github.com/ash-project/ash_graphql/compare/v0.15.0...v0.15.1) (2021-04-05)




### Bug Fixes:

* fully remove relationship changes

### Improvements:

* support `upsert?: true` flag on `create`

## [v0.15.0](https://github.com/ash-project/ash_graphql/compare/v0.14.1...v0.15.0) (2021-04-05)
### Breaking Changes:

* fully remove relationship changes



## [v0.14.1](https://github.com/ash-project/ash_graphql/compare/v0.14.0...v0.14.1) (2021-04-05)




### Improvements:

* add allow_nil? to queries (#16)

## [v0.14.0](https://github.com/ash-project/ash_graphql/compare/v0.13.1...v0.14.0) (2021-04-04)




### Features:

* add read_one query (#13)

### Improvements:

* update to latest ash

* generate type based on allow_nil? (#14)

## [v0.13.1](https://github.com/ash-project/ash_graphql/compare/v0.13.0...v0.13.1) (2021-04-03)




### Bug Fixes:

* update to latest ash

## [v0.13.0](https://github.com/ash-project/ash_graphql/compare/v0.12.7...v0.13.0) (2021-03-28)




### Features:

* support custom types, add custom type test

### Bug Fixes:

* select fields/aggregates/calculations

## [v0.12.7](https://github.com/ash-project/ash_graphql/compare/v0.12.6...v0.12.7) (2021-03-15)




### Improvements:

* update ash version

## [v0.12.6](https://github.com/ash-project/ash_graphql/compare/v0.12.5...v0.12.6) (2021-03-15)




### Bug Fixes:

* properly handle relationship changes on updates

### Improvements:

* start on error messaging groundwork

## [v0.12.5](https://github.com/ash-project/ash_graphql/compare/v0.12.4...v0.12.5) (2021-03-12)




### Bug Fixes:

* allow referencing ash generated types

* don't fail on empty mutations list

### Improvements:

* support more builtin types

## [v0.12.4](https://github.com/ash-project/ash_graphql/compare/v0.12.3...v0.12.4) (2021-03-08)




### Improvements:

* validate action existence

## [v0.12.3](https://github.com/ash-project/ash_graphql/compare/v0.12.2...v0.12.3) (2021-02-23)




### Bug Fixes:

* fix .formatter.exs

## [v0.12.2](https://github.com/ash-project/ash_graphql/compare/v0.12.1...v0.12.2) (2021-02-23)




### Improvements:

* support `debug?` at the api level

## [v0.12.1](https://github.com/ash-project/ash_graphql/compare/v0.12.0...v0.12.1) (2021-02-23)




### Bug Fixes:

* proper supports for embeds

### Improvements:

* update to latest ash

## [v0.12.0](https://github.com/ash-project/ash_graphql/compare/v0.11.0-rc0...v0.12.0) (2021-01-22)




### Improvements:

* support latest ash

## [v0.11.0-rc0](https://github.com/ash-project/ash_graphql/compare/v0.10.0...v0.11.0-rc0) (2021-01-22)




### Features:

* update to latest ash

* support query arguments

## [v0.10.0](https://github.com/ash-project/ash_graphql/compare/v0.9.5...v0.10.0) (2021-01-12)




### Features:

* support embedded resources

## [v0.9.5](https://github.com/ash-project/ash_graphql/compare/v0.9.4...v0.9.5) (2021-01-08)




### Improvements:

* support latest ash version

## [v0.9.4](https://github.com/ash-project/ash_graphql/compare/v0.9.3...v0.9.4) (2020-12-30)




### Bug Fixes:

* `in` enum filters should be instances of the enum

## [v0.9.3](https://github.com/ash-project/ash_graphql/compare/v0.9.2...v0.9.3) (2020-12-30)




### Bug Fixes:

* resolve error with non-required pagination

## [v0.9.2](https://github.com/ash-project/ash_graphql/compare/v0.9.1...v0.9.2) (2020-12-30)




## [v0.9.1](https://github.com/ash-project/ash_graphql/compare/v0.9.0...v0.9.1) (2020-12-30)




### Bug Fixes:

* properly represent boolean filters

## [v0.9.0](https://github.com/ash-project/ash_graphql/compare/v0.8.0...v0.9.0) (2020-12-29)




### Features:

* filters as input objects

### Improvements:

* update to latest ash

## [v0.8.0](https://github.com/ash-project/ash_graphql/compare/v0.7.5...v0.8.0) (2020-12-02)




### Features:

* support arguments

### Bug Fixes:

* resolve testing compilation errors

## [v0.7.5](https://github.com/ash-project/ash_graphql/compare/v0.7.4...v0.7.5) (2020-12-01)




### Bug Fixes:

* don't require attributes that have a default value

## [v0.7.4](https://github.com/ash-project/ash_graphql/compare/v0.7.3...v0.7.4) (2020-12-01)




### Bug Fixes:

* remove IO.inspect

## [v0.7.3](https://github.com/ash-project/ash_graphql/compare/v0.7.2...v0.7.3) (2020-12-01)




### Bug Fixes:

* undo change of global types

## [v0.7.2](https://github.com/ash-project/ash_graphql/compare/v0.7.1...v0.7.2) (2020-12-01)




### Bug Fixes:

* always add global types

## [v0.7.1](https://github.com/ash-project/ash_graphql/compare/v0.7.0...v0.7.1) (2020-11-30)




### Bug Fixes:

* require absinthe_plug

## [v0.7.0](https://github.com/ash-project/ash_graphql/compare/v0.6.3...v0.7.0) (2020-11-18)




### Features:

* Support configuring identities (#8)

* support using identities for gets

## [v0.6.3](https://github.com/ash-project/ash_graphql/compare/v0.6.2...v0.6.3) (2020-11-12)




### Bug Fixes:

* correct sorting enum/args list

### Improvements:

* create input honors required relationships

* add more NonNulls

## [v0.6.2](https://github.com/ash-project/ash_graphql/compare/v0.6.1...v0.6.2) (2020-11-06)




### Bug Fixes:

* allow null sorts

## [v0.6.1](https://github.com/ash-project/ash_graphql/compare/v0.6.0...v0.6.1) (2020-11-06)




### Bug Fixes:

* default_page_size -> default_limit

## [v0.6.0](https://github.com/ash-project/ash_graphql/compare/v0.5.0...v0.6.0) (2020-11-06)




### Features:

* overhaul, better type support, pagination

### Bug Fixes:

* use the correct tenant function

## [v0.5.0](https://github.com/ash-project/ash_graphql/compare/v0.4.0...v0.5.0) (2020-10-28)




### Features:

* support multitenancy (#7)

## [v0.4.0](https://github.com/ash-project/ash_graphql/compare/v0.3.2...v0.4.0) (2020-10-10)




### Features:

* update to latest ash

### Bug Fixes:

* fix usage of new Ash.Query.filter/2

## [v0.3.2](https://github.com/ash-project/ash_graphql/compare/v0.3.1...v0.3.2) (2020-09-28)




### Bug Fixes:

* set api_opts properly

## [v0.3.1](https://github.com/ash-project/ash_graphql/compare/v0.3.0...v0.3.1) (2020-09-28)




### Bug Fixes:

* dataloader errors w/ associations

## [v0.3.0](https://github.com/ash-project/ash_graphql/compare/v0.2.1...v0.3.0) (2020-09-24)




### Features:

* rewrite with dataloader

* rewrite with dataloader

### Bug Fixes:

* use module name specific to the api

* support booleans

## [v0.2.1](https://github.com/ash-project/ash_graphql/compare/v0.2.0...v0.2.1) (2020-08-26)




### Bug Fixes:

* use `InputObjectDefinition` for relationship change

## [v0.2.0](https://github.com/ash-project/ash_graphql/compare/v0.1.3...v0.2.0) (2020-08-18)




### Features:

* update to latest ash

## [v0.1.3](https://github.com/ash-project/ash_graphql/compare/v0.1.2...v0.1.3) (2020-08-17)




### Bug Fixes:

* don't add graphql types if API doesn't compile

## [v0.1.2](https://github.com/ash-project/ash_graphql/compare/v0.1.1...v0.1.2) (2020-08-14)




### Bug Fixes:

* get mix check passing

* include initial files

## [v0.1.1](https://github.com/ash-project/ash_graphql/compare/v0.1.0...v0.1.1) (2020-08-13)




### Bug Fixes:

* include initial files

## [v0.1.0](https://github.com/ash-project/ash_graphql/compare/v0.1.0...v0.1.0) (2020-08-13)




### Features:

* initial POC release
