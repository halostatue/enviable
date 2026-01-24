defmodule Enviable.ConversionTest do
  use ExUnit.Case

  alias Elixir.Enviable.MakeItUp
  alias Enviable.Conversion

  paths = Path.wildcard("test/fixtures/*.pem")
  @paths_hash :erlang.md5(paths)

  for path <- paths, do: @external_resource(path)

  @pems Map.new(paths, &{Path.basename(&1, ".pem"), &1})
  defp pems(name), do: @pems[name]

  def __mix_recompile__?, do: :erlang.md5(Path.wildcard("test/fixtures/*.pem")) != @paths_hash

  doctest Enviable.Conversion

  defmodule JsonModule do
    @moduledoc false
    def decode_json(v, opts \\ [])
    def decode_json("raise", _opts), do: raise("raise")
    def decode_json(v, opts), do: Jason.decode(v, opts)

    def decode(v, opts \\ []), do: decode_json(v, opts)
  end

  setup do
    System.delete_env("PORT")
    System.delete_env("COLOR")
    System.delete_env("NAME")
  end

  describe "conversion: atom" do
    test "value nil" do
      assert nil == convert_as(nil, :atom)
    end

    test "value nil with default" do
      assert :default == convert_as(nil, :atom, default: :default)
    end

    test "value nil with default and allowed" do
      assert :on == convert_as(nil, :atom, allowed: ~w[on off]a, default: "on")
    end

    test "value with downcase" do
      assert :default == convert_as("DEFAULT", :atom, downcase: true)
      assert :DEFAULT == convert_as("DEFAULT", :atom, downcase: false)
    end

    test "value with upcase" do
      assert :default == convert_as("default", :atom, upcase: false)
      assert :DEFAULT == convert_as("default", :atom, upcase: true)
    end

    test "value with allowed" do
      assert :on == convert_as("on", :atom, allowed: ~w[on off]a)
    end

    test "value with downcase and allowed" do
      assert :off == convert_as("OFF", :atom, downcase: true, allowed: ~w[on off]a)
      assert_conversion_error("OFF", :atom, downcase: false, allowed: ~w[on off]a)
    end

    test "value with default not in allowed" do
      assert_config_error(
        "`default` value 'unset' not present in `allowed`",
        "on",
        :atom,
        allowed: ~w[on off]a,
        default: :unset
      )

      assert_config_error(
        "`default` value 'unset' not present in `allowed`",
        "on",
        :atom,
        allowed: ~w[on off]a,
        default: "unset"
      )

      assert_config_error(
        "non-atom `default` value",
        "on",
        :atom,
        allowed: ~w[on off]a,
        default: 3
      )
    end

    test "value not in allowed" do
      assert_conversion_error("unset", :atom, allowed: ~w[on off]a)
    end

    test "invalid allowed" do
      assert_config_error("`allowed` must be an atom list", "on", :atom, allowed: 3)
      assert_config_error("`allowed` cannot be empty", "on", :atom, allowed: [])
    end

    test "invalid downcase" do
      assert_config_error("invalid `downcase` value", "on", :atom, downcase: 3)
    end

    test "invalid upcase" do
      assert_config_error("invalid `upcase` value", "on", :atom, upcase: 3)
    end

    test "both upcase and downcase provided" do
      assert_config_error(
        "`downcase` and `upcase` options both provided",
        "on",
        :atom,
        upcase: true,
        downcase: true
      )
    end
  end

  describe "conversion: safe_atom" do
    test "value nil" do
      assert nil == convert_as(nil, :safe_atom)
    end

    test "value nil with default" do
      assert :default == convert_as(nil, :safe_atom, default: :default)
    end

    test "value nil with default and allowed" do
      assert :on == convert_as(nil, :safe_atom, allowed: ~w[on off]a, default: "on")
    end

    test "value atom does not already exist" do
      assert_raise ArgumentError, ~r/not an already existing atom/, fn ->
        convert_as("DDEEFFAAUULLTT", :safe_atom)
      end
    end

    test "value with downcase" do
      assert :default == convert_as("DEFAULT", :safe_atom, downcase: true)
      assert :DEFAULT == convert_as("DEFAULT", :safe_atom, downcase: false)
    end

    test "value with downcase and allowed" do
      assert :off == convert_as("OFF", :safe_atom, downcase: true, allowed: ~w[on off]a)
      assert_conversion_error("OFF", :safe_atom, downcase: false, allowed: ~w[on off]a)
    end

    test "value with allowed" do
      assert :on == convert_as("on", :safe_atom, allowed: ~w[on off]a)
    end

    test "value with default not in allowed" do
      assert_config_error(
        "`default` value 'unset' not present in `allowed`",
        "on",
        :safe_atom,
        allowed: ~w[on off]a,
        default: :unset
      )

      assert_config_error(
        "`default` value 'unset' not present in `allowed`",
        "on",
        :safe_atom,
        allowed: ~w[on off]a,
        default: "unset"
      )

      assert_config_error(
        "non-atom `default` value",
        "on",
        :safe_atom,
        allowed: ~w[on off]a,
        default: 3
      )
    end

    test "value not in allowed" do
      assert_conversion_error("DDEEFFAAUULLTT", :safe_atom, allowed: ~w[on off]a)
    end

    test "invalid allowed" do
      assert_config_error("`allowed` must be an atom list", "on", :safe_atom, allowed: 3)
      assert_config_error("`allowed` cannot be empty", "on", :safe_atom, allowed: [])
    end
  end

  describe "conversion: boolean" do
    test "value nil" do
      assert false == convert_as(nil, :boolean)
    end

    test "value nil with default true" do
      assert true == convert_as(nil, :boolean, default: true)
    end

    test "value compared to default truthy (1, true)" do
      assert true == convert_as("1", :boolean)
      assert true == convert_as("true", :boolean)
      assert true == convert_as("TRUE", :boolean)
    end

    test "value with downcase" do
      assert true == convert_as("TRUE", :boolean, downcase: true)
      assert false == convert_as("TRUE", :boolean, downcase: false)
    end

    test "value compared to falsy (0, false)" do
      assert true == convert_as("1", :boolean, falsy: ~w[0 false])
      assert false == convert_as("0", :boolean, falsy: ~w[0 false])
      assert false == convert_as("false", :boolean, falsy: ~w[0 false])
    end

    test "both falsy and truthy provided" do
      assert_config_error(
        "`truthy` and `falsy` options both provided",
        "1",
        :boolean,
        truthy: ~w[1 true],
        falsy: ~w[0 false]
      )
    end
  end

  describe "conversion: integer" do
    test "value nil" do
      assert nil == convert_as(nil, :integer)
    end

    test "value nil with default" do
      assert 3 == convert_as(nil, :integer, default: 3)
      assert 5 == convert_as(nil, :integer, default: "5")
    end

    test "value integer" do
      assert 3 == convert_as("3", :integer)
    end

    test "value non-integer" do
      assert_conversion_error("X", :integer)
    end

    test "value partial integer" do
      assert_conversion_error("3X", :integer)
    end

    test "invalid base" do
      assert_config_error("invalid `base` value (must be an integer 2..36)", "1", :integer, base: 37)
    end

    test "string base" do
      assert_config_error("invalid `base` value (must be an integer 2..36)", "1", :integer, base: "2")
    end

    test "value not in base" do
      assert_conversion_error("8", :integer, base: 8)
    end

    test "default string not in base" do
      assert_config_error("non-integer `default` value for base 8", "1", :integer, base: 8, default: "8")
    end

    test "non-integer default" do
      assert_config_error("non-integer `default` value", "1", :integer, default: 3.5)
    end
  end

  describe "conversion: charlist" do
    test "value nil" do
      assert nil == convert_as(nil, :charlist)
    end

    test "value nil with default" do
      assert ~c"default" == convert_as(nil, :charlist, default: "default")
      assert ~c"default" == convert_as(nil, :charlist, default: ~c"default")
    end

    test "invalid default" do
      assert_config_error("non-charlist `default` value", nil, :charlist, default: 1)
    end

    test "valid value" do
      assert ~c"value" == convert_as("value", :charlist)
    end
  end

  describe "conversion: float" do
    test "value nil" do
      assert nil == convert_as(nil, :float)
    end

    test "value nil with default" do
      assert 3.1 === convert_as(nil, :float, default: 3.1)
      assert 5.1 === convert_as(nil, :float, default: "5.1")
      assert 7.0 === convert_as(nil, :float, default: 7)
      assert is_float(convert_as(nil, :float, default: 3.1))
      assert is_float(convert_as(nil, :float, default: "5.1"))
      assert is_float(convert_as(nil, :float, default: 7))
    end

    test "value float" do
      assert 3.0 === convert_as("3", :float)
      assert is_float(convert_as("3", :float))
      assert 3.5 === convert_as("3.5", :float)
    end

    test "value non-float" do
      assert_conversion_error("X", :float)
    end

    test "value partial float" do
      assert_conversion_error("3X", :float)
    end

    test "non-float default" do
      assert_config_error("non-float `default` value", "1", :float, default: :atom)
      assert_config_error("non-float `default` value", "1", :float, default: "3X")
    end
  end

  describe "conversion: json" do
    test "value nil" do
      assert nil == convert_as(nil, :json)
    end

    test "value nil with default" do
      assert 3.1 === convert_as(nil, :json, default: 3.1)
      assert 3 === convert_as(nil, :json, default: 3)
      assert "3" == convert_as(nil, :json, default: "3")
      assert %{} == convert_as(nil, :json, default: %{})
      assert [] == convert_as(nil, :json, default: [])
      assert true == convert_as(nil, :json, default: true)
    end

    test "value json" do
      assert 3.1 === convert_as("3.1", :json)
      assert 3 === convert_as("3", :json)
      assert "3" == convert_as("\"3\"", :json)
      assert %{} == convert_as("{}", :json)
      assert [] == convert_as("[]", :json)
      assert true == convert_as("true", :json)
    end

    test "value non-json" do
      assert_conversion_error("X", :json)
    end

    test "non-json default" do
      assert_config_error("non-JSON `default` value", "1", :json, default: :atom)
    end

    test "invalid engine" do
      assert_config_error("invalid `engine` value", "1", :json, engine: "engine")
    end

    test "with engine Jason" do
      assert 3.1 === convert_as("3.1", :json, engine: Jason)
      assert 3 === convert_as("3", :json, engine: Jason)
      assert "3" == convert_as("\"3\"", :json, engine: Jason)
      assert %{} == convert_as("{}", :json, engine: Jason)
      assert [] == convert_as("[]", :json, engine: Jason)
      assert true == convert_as("true", :json, engine: Jason)
      assert nil == convert_as("null", :json, engine: Jason)
      assert_conversion_error("xyz", :json, engine: Jason)
    end

    test "with function engine" do
      assert_conversion_error("3.1", :json, engine: fn _ -> :error end)
      assert_conversion_error("3.1", :json, engine: fn _ -> raise "foo" end)
      assert 3.1 === convert_as("3.1", :json, engine: fn v -> Jason.decode(v) end)
    end

    test "with atom engine" do
      assert 3.1 === convert_as("3.1", :json, engine: JsonModule)
      assert 3 === convert_as("3", :json, engine: JsonModule)
      assert "3" == convert_as("\"3\"", :json, engine: JsonModule)
      assert %{} == convert_as("{}", :json, engine: JsonModule)
      assert [] == convert_as("[]", :json, engine: JsonModule)
      assert true == convert_as("true", :json, engine: JsonModule)
      assert_conversion_error("xyz", :json, engine: JsonModule)
      assert_conversion_error("raise", :json, engine: JsonModule)
    end

    test "with mfa engine" do
      assert 3.1 === convert_as("3.1", :json, engine: {JsonModule, :decode_json, [[]]})
      assert 3 === convert_as("3", :json, engine: {JsonModule, :decode_json, [[]]})
      assert "3" == convert_as("\"3\"", :json, engine: {JsonModule, :decode_json, [[]]})
      assert %{} == convert_as("{}", :json, engine: {JsonModule, :decode_json, [[]]})
      assert [] == convert_as("[]", :json, engine: {JsonModule, :decode_json, [[]]})
      assert true == convert_as("true", :json, engine: {JsonModule, :decode_json, [[]]})
      assert_conversion_error("xyz", :json, engine: {JsonModule, :decode_json, [[]]})
      assert_conversion_error("raise", :json, engine: {JsonModule, :decode_json, [[]]})
    end
  end

  describe "conversion: log_level" do
    test "value nil" do
      assert nil == convert_as(nil, :log_level)
    end

    test "value nil with default" do
      assert :notice == convert_as(nil, :log_level, default: :notice)
      assert :notice == convert_as(nil, :log_level, default: "notice")
    end

    for level <- [:emergency, :alert, :critical, :error, :warning, :warn, :notice, :info, :debug, :all, :none] do
      test "value #{level}" do
        assert unquote(level) == convert_as(Atom.to_string(unquote(level)), :log_level)
        assert unquote(level) == convert_as(String.upcase(Atom.to_string(unquote(level))), :log_level)
      end
    end

    test "value with default not a valid log level" do
      assert_config_error(
        "invalid `default` value :unknown",
        "Emergency",
        :log_level,
        default: :unknown
      )

      assert_config_error(
        "invalid `default` value unknown",
        "Emergency",
        :log_level,
        default: "unknown"
      )
    end

    test "value not in allowed" do
      assert_conversion_error("Unknown", :log_level)
    end
  end

  describe "conversion: module" do
    test "value nil" do
      assert nil == convert_as(nil, :module)
    end

    test "value nil with default" do
      assert Elixir.Enviable == convert_as(nil, :module, default: Enviable)
    end

    test "value" do
      assert MakeItUp == convert_as("Enviable.MakeItUp", :module)
    end

    test "value with allowed" do
      assert Elixir.Enviable == convert_as("Enviable", :module, allowed: [Enviable, System])
      assert Elixir.System == convert_as("System", :module, allowed: [Enviable, System])
    end

    test "value with default not in allowed" do
      assert_config_error(
        "`default` value 'Elixir.Code' not present in `allowed`",
        "System",
        :module,
        allowed: ~w[Enviable System]a,
        default: Code
      )

      assert_config_error(
        "`default` value 'Code' not present in `allowed`",
        "System",
        :module,
        allowed: ~w[Enviable System]a,
        default: "Code"
      )

      assert_config_error(
        "non-atom `default` value",
        "System",
        :module,
        allowed: ~w[Enviable System]a,
        default: 3
      )
    end

    test "value not in allowed" do
      assert_conversion_error("Code", :module, allowed: [Enviable, System])
    end

    test "invalid allowed" do
      assert_config_error("`allowed` must be an atom list", "on", :module, allowed: 3)
      assert_config_error("`allowed` cannot be empty", "on", :module, allowed: [])
    end
  end

  describe "conversion: safe_module" do
    test "value nil" do
      assert nil == convert_as(nil, :safe_module)
    end

    test "value nil with default" do
      assert Elixir.Enviable == convert_as(nil, :safe_module, default: Enviable)
    end

    test "value module does not already exist" do
      assert_raise ArgumentError, ~r/not an already existing atom/, fn ->
        convert_as("Enviable.DoesNotExist", :safe_module)
      end
    end

    test "value with allowed" do
      assert Elixir.Enviable == convert_as("Enviable", :safe_module, allowed: [Enviable, System])
      assert Elixir.System == convert_as("System", :safe_module, allowed: [Enviable, System])
    end

    test "value with default not in allowed" do
      assert_config_error(
        "`default` value 'Elixir.Code' not present in `allowed`",
        "System",
        :safe_module,
        allowed: ~w[Enviable System]a,
        default: Code
      )

      assert_config_error(
        "`default` value 'Code' not present in `allowed`",
        "System",
        :safe_module,
        allowed: ~w[Enviable System]a,
        default: "Code"
      )

      assert_config_error(
        "non-atom `default` value",
        "System",
        :safe_module,
        allowed: ~w[Enviable System]a,
        default: 3
      )
    end

    test "value not in allowed" do
      assert_conversion_error("DDEEFFAAUULLTT", :safe_module, allowed: ~w[on off]a)
    end

    test "invalid allowed" do
      assert_config_error("`allowed` must be an atom list", "on", :safe_module, allowed: 3)
      assert_config_error("`allowed` cannot be empty", "on", :safe_module, allowed: [])
    end
  end

  describe "conversion: pem" do
    setup do
      {:ok, key_pem: File.read!(pems("example.org-key")), cert_pem: File.read!(pems("example.org"))}
    end

    test "value nil" do
      assert nil == convert_as(nil, :pem)
    end

    test "private key PEM default behaviour", %{key_pem: value} do
      assert {:PrivateKeyInfo, _} = convert_as(value, :pem)
    end

    test "certificates PEM default behaviour", %{cert_pem: value} do
      assert [_] = convert_as(value, :pem)
    end

    test "private key PEM no filtering", %{key_pem: value} do
      assert [{:PrivateKeyInfo, _, :not_encrypted}] = convert_as(value, :pem, filter: false)
    end

    test "certificates PEM no filtering", %{cert_pem: value} do
      assert [{:Certificate, _, :not_encrypted}] = convert_as(value, :pem, filter: false)
    end

    test "private key PEM filter: :cert fails", %{key_pem: value} do
      assert_conversion_error(value, :pem, filter: :cert)
    end

    test "private key PEM filter: :key", %{key_pem: value} do
      assert {:PrivateKeyInfo, _} = convert_as(value, :pem, filter: :key)
    end

    test "certificates PEM filter: :key fails", %{cert_pem: value} do
      assert_conversion_error(value, :pem, filter: :key)
    end

    test "certificates PEM filter: :cert", %{cert_pem: value} do
      assert [_] = convert_as(value, :pem, filter: :cert)
    end

    test "certificates PEM invalid filter", %{cert_pem: value} do
      assert_config_error("invalid `filter` value", value, :pem, filter: nil)
    end
  end

  describe "conversion: term (erlang)" do
    test "value nil" do
      assert nil == convert_as(nil, :erlang)
    end

    test "value correct term" do
      assert {:ok, 1} == convert_as("{ok, 1}.", :erlang)
    end

    test "value incorrect syntax (no terminal .)" do
      assert_conversion_error("{ok, 1}", :erlang)
    end

    test "value incorrect syntax ('a)" do
      assert_conversion_error("'a", :erlang)
    end
  end

  describe "conversion: term (elixir)" do
    test "value nil" do
      assert nil == convert_as(nil, :elixir)
    end

    test "value correct term" do
      assert 1..3//2 == convert_as("1..3//2", :elixir)
    end

    test "value incorrect syntax (1..3//0)" do
      assert_raise ArgumentError, fn ->
        convert_as("1..3//0", :elixir)
      end
    end

    test "value incorrect syntax (\"a)" do
      assert_conversion_error("\"a", :elixir)
    end
  end

  describe "conversion: base16" do
    test "value nil" do
      assert nil == convert_as(nil, :base16)
    end

    test "value 666F6F626172, case :upper (default)" do
      assert "foobar" == convert_as("666F6F626172", :base16)
      assert "foobar" == convert_as("666F6F626172", :base16, case: :upper)
      assert_conversion_error("666f6f626172", :base16, case: :upper)
    end

    test "value 666f6f626172, case :lower" do
      assert "foobar" == convert_as("666f6f626172", :base16, case: :lower)
      assert_conversion_error("666F6F626172", :base16, case: :lower)
    end

    test "value 666f6F626172, case :mixed" do
      assert "foobar" == convert_as("666f6F626172", :base16, case: :mixed)
      assert "foobar" == convert_as("666f6f626172", :base16, case: :mixed)
      assert "foobar" == convert_as("666F6F626172", :base16, case: :mixed)
    end

    test "value {:base16, :integer}" do
      assert 65_535 == convert_as("3635353335", {:base16, :integer})
    end

    test "invalid case option" do
      assert_config_error("invalid `case` value", "ff", :base16, case: :foo)
    end
  end

  describe "conversion: base32" do
    test "value nil" do
      assert nil == convert_as(nil, :base32)
    end

    test "value MZXW6YTBOI case :upper, padding false (default)" do
      assert "foobar" == convert_as("MZXW6YTBOI======", :base32, case: :upper)
      assert "foobar" == convert_as("MZXW6YTBOI", :base32, case: :upper)
      assert_conversion_error("MZXw6ytboi======", :base32, case: :upper)
      assert_conversion_error("MZXw6ytboi", :base32, case: :upper)
    end

    test "value mzxw6ytboi case :lower, padding false (default)" do
      assert "foobar" == convert_as("mzxw6ytboi======", :base32, case: :lower)
      assert "foobar" == convert_as("mzxw6ytboi", :base32, case: :lower)
      assert_conversion_error("MZXW6YTBOI======", :base32, case: :lower)
      assert_conversion_error("MZXW6YTBOI", :base32, case: :lower)
    end

    test "value MZXw6ytboi case :mixed (default), padding false (default)" do
      assert "foobar" == convert_as("mzxw6ytboi======", :base32)
      assert "foobar" == convert_as("mzxw6ytboi", :base32)
      assert "foobar" == convert_as("mzxw6YTBOI======", :base32)
      assert "foobar" == convert_as("mzxw6YTBOI", :base32)
    end

    test "value MZXW6YTBOI case :upper (default), padding true" do
      assert "foobar" == convert_as("MZXW6YTBOI======", :base32, padding: true)
      assert_conversion_error("MZXW6YTBOI", :base32, padding: true)
    end

    test "value {:base32, :integer}" do
      assert 65_535 == convert_as("GY2TKMZV", {:base32, :integer})
    end

    test "invalid case option" do
      assert_config_error("invalid `case` value", "ff", :base32, case: :foo)
    end

    test "invalid padding option" do
      assert_config_error("invalid `padding` value", "ff", :base32, padding: nil)
    end
  end

  describe "conversion: hex32" do
    test "value nil" do
      assert nil == convert_as(nil, :hex32)
    end

    test "value CPNMUOJ1E8 case :upper (default), padding false (default)" do
      assert "foobar" == convert_as("CPNMUOJ1E8======", :hex32, case: :upper)
      assert "foobar" == convert_as("CPNMUOJ1E8", :hex32, case: :upper)
      assert_conversion_error("CPNmuoj1e8======", :hex32, case: :upper)
      assert_conversion_error("CPNmuoj1e8", :hex32, case: :upper)
    end

    test "value cpnmuoj1e8 case :lower, padding false (default)" do
      assert "foobar" == convert_as("cpnmuoj1e8======", :hex32, case: :lower)
      assert "foobar" == convert_as("cpnmuoj1e8", :hex32, case: :lower)
      assert_conversion_error("CPNMUOJ1E8======", :hex32, case: :lower)
      assert_conversion_error("CPNMUOJ1E8", :hex32, case: :lower)
    end

    test "value CPNMUOJ1E8 case :mixed (default), padding false (default)" do
      assert "foobar" == convert_as("CPNMUOJ1E8======", :hex32)
      assert "foobar" == convert_as("CPNMUOJ1E8", :hex32)
      assert "foobar" == convert_as("cpnmuoj1e8======", :hex32)
      assert "foobar" == convert_as("cpnmuoj1e8", :hex32)
    end

    test "value CPNMUOJ1E8 case :upper (default), padding true" do
      assert "foobar" == convert_as("CPNMUOJ1E8======", :hex32, padding: true)
      assert_conversion_error("CPNMUOJ1E8", :hex32, padding: true)
    end

    test "value {:hex32, :integer}" do
      assert 65_535 == convert_as("6OQJACPL", {:hex32, :integer})
    end

    test "invalid case option" do
      assert_config_error("invalid `case` value", "ff", :hex32, case: :foo)
    end

    test "invalid padding option" do
      assert_config_error("invalid `padding` value", "ff", :hex32, padding: nil)
    end
  end

  describe "conversion: base64" do
    setup do
      data = File.read!(pems("example.org"))
      {:ok, data: data, base64: Base.encode64(data)}
    end

    test "value nil" do
      assert nil == convert_as(nil, :base64)
    end

    test "value padding false (default) ignore whitespace true (default)", ctx do
      assert ctx.data == convert_as(ctx.base64, :base64)
      assert ctx.data == convert_as(trim_padding(ctx.base64), :base64)
      assert ctx.data == convert_as(split_lines(ctx.base64), :base64)
      assert ctx.data == convert_as(split_lines(trim_padding(ctx.base64)), :base64)
    end

    test "value padding true ignore whitespace true (default)", ctx do
      assert ctx.data == convert_as(ctx.base64, :base64, padding: true)
      assert ctx.data == convert_as(split_lines(ctx.base64), :base64, padding: true)
      assert_conversion_error(trim_padding(ctx.base64), :base64, padding: true)
      assert_conversion_error(split_lines(trim_padding(ctx.base64)), :base64, padding: true)
    end

    test "value padding false (default) ignore whitespace false", ctx do
      assert ctx.data == convert_as(ctx.base64, :base64, ignore_whitespace: false)
      assert ctx.data == convert_as(trim_padding(ctx.base64), :base64, ignore_whitespace: false)
      assert_conversion_error(split_lines(ctx.base64), :base64, ignore_whitespace: false)
      assert_conversion_error(split_lines(trim_padding(ctx.base64)), :base64, ignore_whitespace: false)
    end

    test "value as {:base64, :pem}", ctx do
      assert [_] = convert_as(ctx.base64, {:base64, :pem})
    end

    test "invalid ignore_whitespace option" do
      assert_config_error("invalid `ignore_whitespace` value", "ff", :base64, ignore_whitespace: nil)
    end

    test "invalid padding option" do
      assert_config_error("invalid `padding` value", "ff", :base64, padding: nil)
    end
  end

  describe "conversion: list" do
    test "value nil" do
      assert nil == convert_as(nil, :list)
    end

    test "value nil with default" do
      assert [1, 2, 3] == convert_as(nil, :list, default: [1, 2, 3])
    end

    test "invalid default" do
      assert_config_error("non-list `default` value", "1,2;3", :list, default: 3)
    end

    test "defaults" do
      assert ["1", "2", "3"] == convert_as("1,2,3", :list)
    end

    test "value as {:list, :integer} default delimiter" do
      assert [1, 2, 3] == convert_as("1,2,3", {:list, :integer})
    end

    test "non-default delimiter" do
      assert ["1", "2", "3"] == convert_as("1;2;3", :list, delimiter: ";")
    end

    test "list delimiter" do
      assert ["1", "2", "3"] == convert_as("1,2;3", :list, delimiter: [",", ";"])
    end

    test "regex delimiter" do
      assert ["1", "2", "3"] == convert_as("1,2;3", :list, delimiter: ~r/[,;]/)
    end

    test "binary pattern delimiter" do
      assert ["1", "2", "3"] == convert_as("1,2;3", :list, delimiter: :binary.compile_pattern([",", ";"]))
    end

    test "invalid delimiter" do
      assert_config_error("invalid `delimiter` value", "1,2;3", :list, delimiter: nil)
    end

    test "parts: 2" do
      assert ["1", "2,3"] == convert_as("1,2,3", :list, parts: 2)
    end

    test "parts: :infinity" do
      assert ["1", "2", "3"] == convert_as("1,2,3", :list, parts: :infinity)
    end

    test "invalid parts" do
      assert_config_error("invalid `parts` value", "1,2,3", :list, parts: -1)
    end

    test "trim: true" do
      assert ["1", "3"] == convert_as("1,,3", :list, trim: true)
    end

    test "trim: false" do
      assert ["1", "", "3"] == convert_as("1,,3", :list, trim: false)
    end

    test "invalid trim" do
      assert_config_error("invalid `trim` value", "1,,3", :list, trim: :invalid)
    end

    @delimiter_re ~r/1(?<a>2)3(?<b>4)/

    test "on: :all_names" do
      assert ["1", "3", ""] == convert_as("1234", :list, delimiter: @delimiter_re, on: :all_names)
    end

    test "on: named capture" do
      assert ["1", "34"] == convert_as("1234", :list, delimiter: @delimiter_re, on: ["a"])
    end

    test "invalid on" do
      assert_config_error("invalid `on` value", "1234", :list, delimiter: @delimiter_re, on: nil)
    end

    test "include_captures: true" do
      assert ["1", "2", "3", "4", ""] ==
               convert_as("1234", :list, delimiter: @delimiter_re, include_captures: true, on: :all_names)
    end

    test "include_captures: false" do
      assert ["1", "3", ""] ==
               convert_as("1234", :list, delimiter: @delimiter_re, on: :all_names, include_captures: false)
    end

    test "invalid include_captures" do
      assert_config_error("invalid `include_captures` value", "1234", :list,
        on: :all_names,
        delimiter: @delimiter_re,
        include_captures: nil
      )
    end
  end

  describe "conversion: timeout" do
    test "value nil" do
      assert :infinity == convert_as(nil, :timeout)
    end

    test "value nil with default" do
      assert :infinity == convert_as(nil, :timeout, default: :infinity)
      assert :infinity == convert_as(nil, :timeout, default: "infinity")
      assert 3 == convert_as(nil, :timeout, default: 3)
      assert 5 == convert_as(nil, :timeout, default: "5")
      assert 5000 == convert_as(nil, :timeout, default: "5s")
      assert 5000 == convert_as(nil, :timeout, default: Duration.new!(second: 5))
    end

    test "value infinity" do
      assert :infinity == convert_as("infinity", :timeout)
    end

    test "value integer (milliseconds)" do
      assert 3 == convert_as("3", :timeout)
    end

    test "value timeout string" do
      assert 5000 == convert_as("5s", :timeout)
    end

    test "invalid timeout string" do
      assert_conversion_error("X", :timeout)
    end

    test "invalid default" do
      assert_config_error("invalid timeout `default` value", "5s", :timeout, default: 1.5)
      assert_config_error("invalid timeout `default` value", "5s", :timeout, default: [bad: :list])
      assert_config_error("invalid timeout `default` value", "5s", :timeout, default: "X")
      assert_config_error("invalid timeout `default` value", "5s", :timeout, default: "15s s")
    end
  end

  describe "conversion: duration" do
    test "value nil" do
      assert nil == convert_as(nil, :duration)
    end

    test "value nil with default" do
      assert %Duration{minute: 3} == convert_as(nil, :duration, default: Duration.new!(minute: 3))
      assert %Duration{day: 3} == convert_as(nil, :duration, default: "P3D")
      assert %Duration{day: 3, hour: -5} == convert_as(nil, :duration, default: "P3DT-5H")
      assert %Duration{day: -3, hour: 5} == convert_as(nil, :duration, default: "-P3DT-5H")
    end

    test "value duration string" do
      assert %Duration{day: 3} == convert_as("P3D", :duration)
      assert %Duration{day: 3, hour: -5} == convert_as("P3DT-5H", :duration)
      assert %Duration{day: -3, hour: 5} == convert_as("-P3DT-5H", :duration)
    end

    test "invalid duration string" do
      assert_conversion_error("X", :duration)
    end

    test "invalid default" do
      assert_config_error("invalid duration `default` value", "5s", :duration, default: 1.5)
      assert_config_error("invalid duration `default` value", "5s", :duration, default: [bad: :list])
      assert_config_error("invalid duration `default` value", "5s", :duration, default: "X")
      assert_config_error("invalid duration `default` value", "5s", :duration, default: "15s s")
    end
  end

  describe "conversion: url_base64" do
    setup do
      data = File.read!(pems("example.org"))
      {:ok, data: data, url_base64: Base.encode64(data)}
    end

    test "value nil" do
      assert nil == convert_as(nil, :url_base64)
    end

    test "value padding false (default) ignore whitespace true (default)", ctx do
      assert ctx.data == convert_as(ctx.url_base64, :url_base64)
      assert ctx.data == convert_as(trim_padding(ctx.url_base64), :url_base64)
      assert ctx.data == convert_as(split_lines(ctx.url_base64), :url_base64)
      assert ctx.data == convert_as(split_lines(trim_padding(ctx.url_base64)), :url_base64)
    end

    test "value padding true ignore whitespace true (default)", ctx do
      assert ctx.data == convert_as(ctx.url_base64, :url_base64, padding: true)
      assert ctx.data == convert_as(split_lines(ctx.url_base64), :url_base64, padding: true)
      assert_conversion_error(trim_padding(ctx.url_base64), :url_base64, padding: true)
      assert_conversion_error(split_lines(trim_padding(ctx.url_base64)), :url_base64, padding: true)
    end

    test "value padding false (default) ignore whitespace false", ctx do
      assert ctx.data == convert_as(ctx.url_base64, :url_base64, ignore_whitespace: false)
      assert ctx.data == convert_as(trim_padding(ctx.url_base64), :url_base64, ignore_whitespace: false)
      assert_conversion_error(split_lines(ctx.url_base64), :url_base64, ignore_whitespace: false)
      assert_conversion_error(split_lines(trim_padding(ctx.url_base64)), :url_base64, ignore_whitespace: false)
    end

    test "value as {:url_base64, :pem}", ctx do
      assert [_] = convert_as(ctx.url_base64, {:url_base64, :pem})
    end

    test "invalid ignore_whitespace option" do
      assert_config_error("invalid `ignore_whitespace` value", "ff", :url_base64, ignore_whitespace: nil)
    end

    test "invalid padding option" do
      assert_config_error("invalid `padding` value", "ff", :url_base64, padding: nil)
    end
  end

  defp assert_config_error(reason, value, type, options) do
    assert_raise ArgumentError, config_error(type, reason), fn ->
      convert_as(value, type, options)
    end
  end

  defp assert_conversion_error(value, type, options \\ []) do
    assert_raise Enviable.ConversionError, conversion_error(type), fn ->
      convert_as(value, type, options)
    end
  end

  defp convert_as(value, type, options \\ []) do
    Conversion.convert_as(value, "VARNAME", type, options)
  end

  defp config_error(type, reason), do: "could not convert environment variable \"VARNAME\" to type #{type}: #{reason}"

  defp conversion_error(type), do: "could not convert environment variable \"VARNAME\" to type #{type}"

  defp split_lines(data) do
    data
    |> String.codepoints()
    |> Enum.chunk_every(80)
    |> Enum.map_join("\n", &Enum.join/1)
  end

  defp trim_padding(data), do: String.trim_trailing(data, "=")
end
