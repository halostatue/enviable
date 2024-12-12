defmodule Enviable do
  @moduledoc "README.md"
             |> File.read!()
             |> String.replace(~r/# Enviable\n\n/, "")

  @external_resource "README.md"
  @doc """
  Set an environment variable value only if it is not yet set.

  ## Examples

      iex> Enviable.put_env_new("PORT", "3000")
      :ok
      iex> Enviable.get_env("PORT")
      "3000"
      iex> Enviable.put_env_new("PORT", "5000")
      :ok
      iex> Enviable.get_env("PORT")
      "3000"
  """
  @spec put_env(String.t(), binary()) :: :ok
  def put_env_new(varname, value) do
    put_env(varname, get_env(varname, value))
  end

  @doc """
  Returns the value of an environment variable as a `t:boolean/0` value.

  By default, the values `"1"` and `"true"` are considered `true` values. Any other value,
  including unset variable, will be considered `false`.

  This function accepts the following conversion options:

  - `truthy`: a list of string values to be compared for truth values. Mutually exclusive
    with `falsy`.
  - `falsy`: a list of string values to be compared for false values. Mutually exclusive
    with `truthy`.
  - `downcase`: either `false` (the default), `true`, or the mode parameter for
    `String.downcase/2` (`:default`, `:ascii`, `:greek`, or `:turkic`).
  - `default`: the default value (which must be `true` or `false`) if the variable is
    unset. In most cases, when `falsy` is provided, `default: true` should also be
    provided.

  ## Examples

      iex> Enviable.get_env_boolean("COLOR")
      false

      iex> Enviable.get_env_boolean("COLOR", default: true)
      true

      iex> Enviable.put_env("COLOR", "1")
      iex> Enviable.get_env_boolean("COLOR")
      true

      iex> Enviable.put_env("COLOR", "something")
      iex> Enviable.get_env_boolean("COLOR")
      false

      iex> Enviable.put_env("COLOR", "oui")
      iex> Enviable.get_env_boolean("COLOR", truthy: ["oui"])
      true

      iex> Enviable.put_env("COLOR", "OUI")
      iex> Enviable.get_env_boolean("COLOR", truthy: ["oui"])
      false
      iex> Enviable.get_env_boolean("COLOR", truthy: ["oui"], downcase: true)
      true

      iex> Enviable.put_env("COLOR", "NON")
      iex> Enviable.get_env_boolean("COLOR", falsy: ["non"])
      true
      iex> Enviable.get_env_boolean("COLOR", falsy: ["non"], downcase: true)
      false

      iex> Enviable.get_env_boolean("COLOR", default: nil)
      ** (ArgumentError) cannot execute Enviable.get_env_boolean/2 with non-boolean `default` value

      iex> Enviable.get_env_boolean("COLOR", downcase: nil)
      ** (ArgumentError) cannot execute Enviable.get_env_boolean/2 with invalid `downcase` value

      iex> Enviable.get_env_boolean("COLOR", truthy: ["oui"], falsy: ["non"])
      ** (ArgumentError) cannot execute Enviable.get_env_boolean/2 with both `truthy` and `falsy` options
  """
  @spec get_env_boolean(String.t(), keyword) :: boolean()
  defdelegate get_env_boolean(varname, opts \\ []), to: Enviable.Boolean

  @doc """
  Returns the value of an environment variable as `{:ok, t:boolean/0}` value or `:error`
  if the variable is unset.

  By default, the values `"1"` and `"true"` are considered `true` values. Any other value
  will be considered `false`.

  This function accepts the following conversion options:

  - `truthy`: a list of string values to be compared for truth values. Mutually exclusive
    with `falsy`.
  - `falsy`: a list of string values to be compared for false values. Mutually exclusive
    with `truthy`.
  - `downcase`: either `false` (the default), `true`, or the mode parameter for
    `String.downcase/2` (`:default`, `:ascii`, `:greek`, or `:turkic`).

  ## Examples

      iex> Enviable.fetch_env_boolean("COLOR")
      :error

      iex> Enviable.put_env("COLOR", "1")
      iex> Enviable.fetch_env_boolean("COLOR")
      {:ok, true}

      iex> Enviable.put_env("COLOR", "something")
      iex> Enviable.fetch_env_boolean("COLOR")
      {:ok, false}

      iex> Enviable.put_env("COLOR", "oui")
      iex> Enviable.fetch_env_boolean("COLOR", truthy: ["oui"])
      {:ok, true}

      iex> Enviable.put_env("COLOR", "OUI")
      iex> Enviable.fetch_env_boolean("COLOR", truthy: ["oui"])
      {:ok, false}
      iex> Enviable.fetch_env_boolean("COLOR", truthy: ["oui"], downcase: true)
      {:ok, true}

      iex> Enviable.put_env("COLOR", "NON")
      iex> Enviable.fetch_env_boolean("COLOR", falsy: ["non"])
      {:ok, true}
      iex> Enviable.fetch_env_boolean("COLOR", falsy: ["non"], downcase: true)
      {:ok, false}

      # Any `default` value is ignored.
      iex> Enviable.fetch_env_boolean("COLOR", default: nil)
      :error

      iex> Enviable.fetch_env_boolean("COLOR", downcase: nil)
      ** (ArgumentError) cannot execute Enviable.fetch_env_boolean/2 with invalid `downcase` value

      iex> Enviable.fetch_env_boolean("COLOR", truthy: ["oui"], falsy: ["non"])
      ** (ArgumentError) cannot execute Enviable.fetch_env_boolean/2 with both `truthy` and `falsy` options
  """
  @spec fetch_env_boolean(String.t(), keyword) :: {:ok, boolean()} | :error
  defdelegate fetch_env_boolean(varname, opts \\ []), to: Enviable.Boolean

  @doc """
  Returns the value of an environment variable as a `t:boolean/0` value or raises an
  exception if the variable is unset.

  By default, the values `"1"` and `"true"` are considered `true` values. Any other value
  will be considered `false`.

  This function accepts the following conversion options:

  - `truthy`: a list of string values to be compared for truth values. Mutually exclusive
    with `falsy`.
  - `falsy`: a list of string values to be compared for false values. Mutually exclusive
    with `truthy`.
  - `downcase`: either `false` (the default), `true`, or the mode parameter for
    `String.downcase/2` (`:default`, `:ascii`, `:greek`, or `:turkic`).

  ## Examples

      iex> Enviable.fetch_env_boolean!("COLOR")
      ** (System.EnvError) could not fetch environment variable "COLOR" because it is not set

      iex> Enviable.put_env("COLOR", "1")
      iex> Enviable.fetch_env_boolean!("COLOR")
      true

      iex> Enviable.put_env("COLOR", "something")
      iex> Enviable.fetch_env_boolean!("COLOR")
      false

      iex> Enviable.put_env("COLOR", "oui")
      iex> Enviable.fetch_env_boolean!("COLOR", truthy: ["oui"])
      true

      iex> Enviable.put_env("COLOR", "OUI")
      iex> Enviable.fetch_env_boolean!("COLOR", truthy: ["oui"])
      false
      iex> Enviable.fetch_env_boolean!("COLOR", truthy: ["oui"], downcase: true)
      true

      iex> Enviable.put_env("COLOR", "NON")
      iex> Enviable.fetch_env_boolean!("COLOR", falsy: ["non"])
      true
      iex> Enviable.fetch_env_boolean!("COLOR", falsy: ["non"], downcase: true)
      false

      # Any `default` value is ignored.
      iex> Enviable.fetch_env_boolean!("COLOR", default: nil)
      ** (System.EnvError) could not fetch environment variable "COLOR" because it is not set

      iex> Enviable.fetch_env_boolean!("COLOR", downcase: nil)
      ** (ArgumentError) cannot execute Enviable.fetch_env_boolean!/2 with invalid `downcase` value

      iex> Enviable.fetch_env_boolean!("COLOR", truthy: ["oui"], falsy: ["non"])
      ** (ArgumentError) cannot execute Enviable.fetch_env_boolean!/2 with both `truthy` and `falsy` options
  """
  @spec fetch_env_boolean!(String.t(), keyword) :: boolean()
  defdelegate fetch_env_boolean!(varname, opts \\ []), to: Enviable.Boolean

  @doc """
  Returns the value of an environment variable as a `t:integer/0` value or `nil` if the
  variable is not set and a `default` is not provided.

  This function accepts the following conversion options:

  - `base`: The base (`2..36`) for integer conversion. Defaults to `10` like
    `String.to_integer/2`.
  - `default`: the default value, which must be either a binary string value or an
    integer. If provided as a binary, this will be interpreted according to the `base`
    option provided.

  Failure to parse a binary string `default` or the value of the environment variable will
  result in an exception.

  ## Examples

      iex> Enviable.get_env_integer("COLOR")
      nil

      iex> Enviable.get_env_integer("COLOR", default: 255)
      255

      iex> Enviable.get_env_integer("COLOR", default: "255")
      255

      iex> Enviable.get_env_integer("COLOR", default: 3.5)
      ** (ArgumentError) cannot execute Enviable.get_env_integer/2 with non-integer `default` value

      iex> Enviable.put_env("COLOR", "1")
      iex> Enviable.get_env_integer("COLOR")
      1

      iex> Enviable.put_env("COLOR", "ff")
      iex> Enviable.get_env_integer("COLOR")
      ** (Enviable.ConversionError) could not convert environment variable "COLOR" to type integer

      iex> Enviable.put_env("COLOR", "ff")
      iex> Enviable.get_env_integer("COLOR", base: 16)
      255
  """
  @spec get_env_integer(String.t(), keyword) :: integer() | nil
  defdelegate get_env_integer(varname, opts \\ []), to: Enviable.Integer

  @doc """
  Returns the value of an environment variable as `{:ok, t:integer/0}` or `:error` if the
  variable is unset.

  This function accepts the following conversion option:

  - `base`: The base (`2..36`) for integer conversion. Defaults to `10` like
    `String.to_integer/2`.

  Failure to parse the value of the environment variable will result in an exception.

  ## Examples

      iex> Enviable.fetch_env_integer("COLOR")
      :error

      iex> Enviable.put_env("COLOR", "1")
      iex> Enviable.fetch_env_integer("COLOR")
      {:ok, 1}

      iex> Enviable.put_env("COLOR", "ff")
      iex> Enviable.fetch_env_integer("COLOR")
      :error

      iex> Enviable.put_env("COLOR", "ff")
      iex> Enviable.fetch_env_integer("COLOR", base: 16)
      {:ok, 255}
  """
  @spec fetch_env_integer(String.t(), keyword) :: {:ok, integer()} | :error
  defdelegate fetch_env_integer(varname, opts \\ []), to: Enviable.Integer

  @doc """
  Returns the value of an environment variable as a `t:integer/0` value or `nil` if the
  variable is not set and a `default` is not provided.

  This function accepts the following conversion options:

  - `base`: The base (`2..36`) for integer conversion. Defaults to `10` like
    `String.to_integer/2`.
  - `default`: the default value, which must be either a binary string value or an
    integer. If provided as a binary, this will be interpreted according to the `base`
    option provided.

  Failure to parse a binary string `default` or the value of the environment variable will
  result in an exception.

  ## Examples

      iex> Enviable.fetch_env_integer!("COLOR")
      ** (System.EnvError) could not fetch environment variable "COLOR" because it is not set

      iex> Enviable.put_env("COLOR", "1")
      iex> Enviable.fetch_env_integer!("COLOR")
      1

      iex> Enviable.put_env("COLOR", "ff")
      iex> Enviable.fetch_env_integer!("COLOR")
      ** (Enviable.ConversionError) could not convert environment variable "COLOR" to type integer

      iex> Enviable.put_env("COLOR", "ff")
      iex> Enviable.fetch_env_integer!("COLOR", base: 16)
      255
  """
  @spec fetch_env_integer!(String.t(), keyword) :: integer() | nil
  defdelegate fetch_env_integer!(varname, opts \\ []), to: Enviable.Integer

  @doc """
  Deletes an environment variable, removing `varname` from the environment.
  """
  @spec delete_env(String.t()) :: :ok
  defdelegate delete_env(varname), to: System

  @doc """
  Returns the value of the given environment variable or :error if not found.

  If the environment variable varname is set, then {:ok, value} is returned where value is
  a string. If varname is not set, :error is returned.

  ## Examples

      iex> Enviable.fetch_env("PORT")
      :error

      iex> Enviable.put_env("PORT", "4000")
      iex> Enviable.fetch_env("PORT")
      {:ok, "4000"}
  """
  @spec fetch_env(String.t()) :: {:ok, String.t()} | :error
  defdelegate fetch_env(varname), to: System

  @doc """
  Returns the value of the given environment variable or raises if not found.

  Same as `get_env/1` but raises instead of returning `nil` when the variable is
  not set.

  ## Examples

      iex> Enviable.fetch_env!("PORT")
      ** (System.EnvError) could not fetch environment variable "PORT" because it is not set

      iex> Enviable.put_env("PORT", "4000")
      iex> Enviable.fetch_env!("PORT")
      "4000"

  """
  @spec fetch_env!(String.t()) :: String.t()
  defdelegate fetch_env!(varname), to: System

  @doc """
  Returns all system environment variables.

  The returned value is a map containing name-value pairs.
  Variable names and their values are strings.
  """
  @spec get_env() :: %{optional(String.t()) => String.t()}
  defdelegate get_env, to: System

  @doc """
  Returns the value of the given environment variable.

  The returned value of the environment variable
  `varname` is a string. If the environment variable
  is not set, returns the string specified in `default` or
  `nil` if none is specified.

  ## Examples

      iex> Enviable.get_env("PORT")
      nil

      iex> Enviable.get_env("PORT", "4001")
      "4001"

      iex> Enviable.put_env("PORT", "4000")
      iex> Enviable.get_env("PORT")
      "4000"
      iex> Enviable.get_env("PORT", "4001")
      "4000"

  """
  @spec get_env(String.t(), default) :: String.t() | default
        when default: String.t() | default
  defdelegate get_env(varname, default \\ nil), to: System

  @doc """
  Sets an environment variable value.

  Sets a new `value` for the environment variable `varname`.
  """
  @spec put_env(String.t(), binary()) :: :ok
  defdelegate put_env(varname, value), to: System

  @doc """
  Sets multiple environment variables.

  Sets a new value for each environment variable corresponding
  to each `{key, value}` pair in `enum`. Keys and non-nil values
  are automatically converted to charlists. `nil` values erase
  the given keys.

  Overall, this is a convenience wrapper around `put_env/2` and
  `delete_env/2` with support for different key and value formats.
  """
  @spec put_env(Enumerable.t()) :: :ok
  defdelegate put_env(var_map), to: System
end
