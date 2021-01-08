# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

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
