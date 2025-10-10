# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule GF.ActiveMemberPolicy do
  @moduledoc false
  use Ash.Policy.SimpleCheck

  # This is used when logging a breakdown of how a policy is applied - see Logging below.
  def describe(_) do
    "Member is active and has given role"
  end

  def match?(%_{} = member, %{resource: _resource} = _context, opts) do
    active? =
      case member do
        %{status: :active} -> true
        _other -> false
      end

    if opts[:role] do
      GF.Member.can_take_role_action?(member, opts[:role])
    else
      active?
    end
  end

  def match?(_actor, _context, _opts) do
    false
  end
end
