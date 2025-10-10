<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Modifying the Resolution

Using the `modify_resolution` option, you can alter the `Absinthe.Resolution`.

`modify_resolution` is an MFA that will be called with the resolution, the query, and the result of the action as the first three arguments. Must return a new `Absinthe.Resolution`.

This can be used to implement things like setting cookies based on resource actions. A method of using resolution context for that is documented [in Absinthe.Plug](https://hexdocs.pm/absinthe_plug/Absinthe.Plug.html#module-before-send)

> ### as_mutation? {: .warning}
>
> If you are modifying the context in a query, then you should also set `as_mutation?` to true and represent this in your graphql as a mutation. See `as_mutation?` for more.
