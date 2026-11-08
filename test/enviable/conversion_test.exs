defmodule Enviable.ConversionTest do
  use Enviable.ConversionCase

  alias Elixir.Enviable.MakeItUp
  alias Enviable.Conversion
  alias Enviable.Value

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
        "`:default` is not present in `:allowed`",
        "on",
        :atom,
        allowed: ~w[on off]a,
        default: :unset
      )

      assert_config_error(
        "`:default` is not present in `:allowed`",
        "on",
        :atom,
        allowed: ~w[on off]a,
        default: "unset"
      )

      assert_config_error(
        "invalid `:default` value (expected atom or string)",
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
      assert_config_error(
        "invalid `:allowed` value (expected a list of atom)",
        "on",
        :atom,
        allowed: 3
      )

      assert_config_error(
        "`:allowed` cannot be empty",
        "on",
        :atom,
        allowed: []
      )
    end

    test "invalid option values are not included in the message" do
      error =
        assert_config_error(
          "invalid `:allowed` value (expected a list of atom)",
          "on",
          :atom,
          allowed: "sekret"
        )

      refute Exception.message(error) =~ "sekret"

      error =
        assert_config_error(
          "invalid `:allowed` value (expected a list of atom)",
          "on",
          :atom,
          allowed: ["sekret"]
        )

      refute Exception.message(error) =~ "sekret"
    end

    test "invalid downcase" do
      assert_config_error(
        "invalid `:downcase` value (expected boolean or one of :default, :ascii, :greek, :turkic)",
        "on",
        :atom,
        downcase: 3
      )
    end

    test "invalid upcase" do
      assert_config_error(
        "invalid `:upcase` value (expected boolean or one of :default, :ascii, :greek, :turkic)",
        "on",
        :atom,
        upcase: 3
      )
    end

    test "both upcase and downcase provided" do
      assert_config_error(
        "`:downcase` and `:upcase` cannot both be provided",
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
      assert_conversion_error("DDEEFFAAUULLTT", :safe_atom)
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
        "`:default` is not present in `:allowed`",
        "on",
        :safe_atom,
        allowed: ~w[on off]a,
        default: :unset
      )

      assert_config_error(
        "`:default` is not present in `:allowed`",
        "on",
        :safe_atom,
        allowed: ~w[on off]a,
        default: "unset"
      )

      assert_config_error(
        "invalid `:default` value (expected atom or string)",
        "on",
        :safe_atom,
        allowed: ~w[on off]a,
        default: 3
      )
    end

    test "value not in allowed" do
      assert_conversion_error(
        "DDEEFFAAUULLTT",
        :safe_atom,
        allowed: ~w[on off]a
      )
    end

    test "invalid allowed" do
      assert_config_error(
        "invalid `:allowed` value (expected a list of atom)",
        "on",
        :safe_atom,
        allowed: 3
      )

      assert_config_error(
        "`:allowed` cannot be empty",
        "on",
        :safe_atom,
        allowed: []
      )
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
        "`:truthy` and `:falsy` cannot both be provided",
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
      assert_config_error(
        "invalid `:base` value (expected an integer in 2..36)",
        "1",
        :integer,
        base: 37
      )
    end

    test "string base" do
      assert_config_error(
        "invalid `:base` value (expected an integer in 2..36)",
        "1",
        :integer,
        base: "2"
      )
    end

    test "value not in base" do
      assert_conversion_error("8", :integer, base: 8)
    end

    test "default string not in base" do
      assert_config_error(
        "`:default` is not a valid base 8 integer",
        "1",
        :integer,
        base: 8,
        default: "8"
      )
    end

    test "non-integer default" do
      assert_config_error(
        "invalid `:default` value (expected integer or string)",
        "1",
        :integer,
        default: 3.5
      )
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
      assert_config_error(
        "invalid `:default` value (expected string or charlist)",
        nil,
        :charlist,
        default: 1
      )
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
      assert_config_error(
        "invalid `:default` value (expected float, integer, or string)",
        "1",
        :float,
        default: :atom
      )

      assert_config_error(
        "`:default` is not a valid float",
        "1",
        :float,
        default: "3X"
      )
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
      assert_config_error(
        "invalid `:default` value (expected a JSON value)",
        "1",
        :json,
        default: :atom
      )
    end

    test "invalid engine" do
      assert_config_error(
        ~S|invalid `:engine` value (expected module, a function of arity 1, or a {module, function, args} tuple)|,
        "1",
        :json,
        engine: "engine"
      )
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
        "invalid `:default` value (expected log level or string)",
        "Emergency",
        :log_level,
        default: :unknown
      )

      assert_config_error(
        "`:default` is not a valid log level",
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
        "`:default` is not present in `:allowed`",
        "System",
        :module,
        allowed: ~w[Enviable System]a,
        default: Code
      )

      assert_config_error(
        "`:default` is not present in `:allowed`",
        "System",
        :module,
        allowed: ~w[Enviable System]a,
        default: "Code"
      )

      assert_config_error(
        "invalid `:default` value (expected module or string)",
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
      assert_config_error("invalid `:allowed` value (expected a list of modules)", "on", :module, allowed: 3)
      assert_config_error("`:allowed` cannot be empty", "on", :module, allowed: [])
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
      assert_conversion_error("Enviable.DoesNotExist", :safe_module)
    end

    test "value with allowed" do
      assert Elixir.Enviable == convert_as("Enviable", :safe_module, allowed: [Enviable, System])
      assert Elixir.System == convert_as("System", :safe_module, allowed: [Enviable, System])
    end

    test "value with default not in allowed" do
      assert_config_error(
        "`:default` is not present in `:allowed`",
        "System",
        :safe_module,
        allowed: ~w[Enviable System]a,
        default: Code
      )

      assert_config_error(
        "`:default` is not present in `:allowed`",
        "System",
        :safe_module,
        allowed: ~w[Enviable System]a,
        default: "Code"
      )

      assert_config_error(
        "invalid `:default` value (expected module or string)",
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
      assert_config_error("invalid `:allowed` value (expected a list of modules)", "on", :safe_module, allowed: 3)

      assert_config_error("`:allowed` cannot be empty", "on", :safe_module, allowed: [])
    end
  end

  describe "conversion: pem" do
    setup do
      {:ok, key_pem: load_pem!("example.org-key"), cert_pem: load_pem!("example.org")}
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
      assert_config_error("invalid `:filter` value (expected boolean or one of :cert, :key)", value, :pem, filter: nil)
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
      assert 1..3//-2 == convert_as("1..3//-2", :elixir)
    end

    test "value incorrect syntax (1..3//0)" do
      assert_raise ArgumentError, fn -> convert_as("1..3//0", :elixir) end
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
      assert_config_error("invalid `:case` value (expected one of :lower, :mixed, :upper)", "ff", :base16, case: :foo)
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
      assert_config_error("invalid `:case` value (expected one of :lower, :mixed, :upper)", "ff", :base32, case: :foo)
    end

    test "invalid padding option" do
      assert_config_error("invalid `:padding` value (expected boolean)", "ff", :base32, padding: nil)
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
      assert_config_error("invalid `:case` value (expected one of :lower, :mixed, :upper)", "ff", :hex32, case: :foo)
    end

    test "invalid padding option" do
      assert_config_error("invalid `:padding` value (expected boolean)", "ff", :hex32, padding: nil)
    end
  end

  describe "conversion: base64" do
    setup do
      data = load_pem!("example.org")
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
      assert_config_error("invalid `:ignore_whitespace` value (expected boolean)", "ff", :base64,
        ignore_whitespace: nil
      )
    end

    test "invalid padding option" do
      assert_config_error("invalid `:padding` value (expected boolean)", "ff", :base64, padding: nil)
    end
  end

  describe "conversion: list" do
    test "value nil" do
      assert nil == convert_as(nil, :list)
    end

    test "value nil with default" do
      assert ["1", "2", "3"] == convert_as(nil, :list, default: ["1", "2", "3"])
    end

    test "invalid default" do
      assert_config_error("invalid `:default` value (expected string or a list)", "1,2;3", :list, default: 3)
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
      assert_config_error(
        "invalid `:delimiter` value (expected string pattern or regular expression)",
        "1,2;3",
        :list,
        delimiter: nil
      )
    end

    test "parts: 2" do
      assert ["1", "2,3"] == convert_as("1,2,3", :list, parts: 2)
    end

    test "parts: :infinity" do
      assert ["1", "2", "3"] == convert_as("1,2,3", :list, parts: :infinity)
    end

    test "invalid parts" do
      assert_config_error("invalid `:parts` value (expected :infinity or positive integer)", "1,2,3", :list, parts: -1)
    end

    test "trim: true" do
      assert ["1", "3"] == convert_as("1,,3", :list, trim: true)
    end

    test "trim: false" do
      assert ["1", "", "3"] == convert_as("1,,3", :list, trim: false)
    end

    test "invalid trim" do
      assert_config_error("invalid `:trim` value (expected boolean)", "1,,3", :list, trim: :invalid)
    end

    @delimiter_re ~r/1(?<a>2)3(?<b>4)/

    test "on: :all_names" do
      assert ["1", "3", ""] == convert_as("1234", :list, delimiter: @delimiter_re, on: :all_names)
    end

    test "on: named capture" do
      assert ["1", "34"] == convert_as("1234", :list, delimiter: @delimiter_re, on: ["a"])
    end

    test "invalid on" do
      assert_config_error(
        "invalid `:on` value (expected one of :all, :first, :all_but_first, :none, :all_names, or a list of capture names)",
        "1234",
        :list,
        delimiter: @delimiter_re,
        on: nil
      )
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
      assert_config_error("invalid `:include_captures` value (expected boolean)", "1234", :list,
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
      assert_config_error(
        "invalid `:default` value (expected timeout, Duration, string, or keyword list of time units)",
        "5s",
        :timeout,
        default: 1.5
      )

      assert_config_error(
        "invalid `:default` value (expected timeout, Duration, string, or keyword list of time units)",
        "5s",
        :timeout,
        default: [bad: :list]
      )

      assert_config_error("`:default` is not a valid timeout", "5s", :timeout, default: "X")
      assert_config_error("`:default` is not a valid timeout", "5s", :timeout, default: "15s s")
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
      assert_config_error("invalid `:default` value (expected Duration or string)", "5s", :duration, default: 1.5)

      assert_config_error("invalid `:default` value (expected Duration or string)", "5s", :duration,
        default: [bad: :list]
      )

      assert_config_error("`:default` is not a valid ISO 8601 duration", "5s", :duration, default: "X")
      assert_config_error("`:default` is not a valid ISO 8601 duration", "5s", :duration, default: "15s s")
    end
  end

  describe "conversion: url_base64" do
    setup do
      data = load_pem!("example.org")
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
      assert_config_error("invalid `:ignore_whitespace` value (expected boolean)", "ff", :url_base64,
        ignore_whitespace: nil
      )
    end

    test "invalid padding option" do
      assert_config_error("invalid `:padding` value (expected boolean)", "ff", :url_base64, padding: nil)
    end
  end

  describe "conversion: string" do
    test "value nil" do
      assert nil == convert_as(nil, :string)
    end

    test "value nil with default" do
      assert "default" == convert_as(nil, :string, default: "default")
    end

    test "value is returned unchanged" do
      assert "Value" == convert_as("Value", :string)
    end

    test "invalid default" do
      assert_config_error("invalid `:default` value (expected string)", nil, :string, default: 1)
    end

    test "decoded values may be non-UTF-8 binaries" do
      assert <<255>> == convert_as(Base.encode16(<<255>>), {:base16, :string})
    end
  end

  describe "conversion types" do
    test "nested encodings are unsupported" do
      for type <- [{:base64, :list}, {:list, :base16}, {:base16, {:list, :integer}}] do
        assert_unsupported_conversion_error("encoded conversions cannot be nested", "1", type)
      end
    end

    test "some primitives cannot be list elements" do
      for type <- [:json, :elixir, :erlang, :pem] do
        assert_unsupported_conversion_error("`#{inspect(type)}` values cannot be list elements", "1", {:list, type})
      end
    end

    test "unlisted primitives may still be decoded" do
      assert %{"a" => 1} == convert_as(Base.url_encode64(~S|{"a":1}|), {:url_base64, :json})
    end

    test "unknown conversion types are unsupported" do
      assert_unsupported_conversion_error("unknown conversion type", 1, t(:bogus))
    end

    test "unsupported types raise before conversion, even for unset values" do
      assert_unsupported_conversion_error("`:json` values cannot be list elements", nil, {:list, :json})
    end
  end

  describe "default preparation" do
    test "string defaults for atoms and modules without :allowed" do
      assert :enviable_default == convert_as(nil, :atom, default: "enviable_default")
      assert Enviable == convert_as(nil, :module, default: "Enviable")
    end

    test "string defaults for safe atoms must be existing atoms" do
      assert :ok == convert_as(nil, :safe_atom, default: "ok")

      assert_config_error(
        "`:default` is not an existing atom",
        nil,
        :safe_atom,
        default: "enviable_not_an_existing_atom_8c1f"
      )
    end

    test "string defaults for safe modules must be existing modules" do
      assert Enviable == convert_as(nil, :safe_module, default: "Enviable")

      assert_config_error(
        "`:default` is not an existing module",
        nil,
        :safe_module,
        default: "Enviable.NotAnExistingModule8c1f"
      )
    end

    test "timeout defaults that cannot be converted to a timeout" do
      assert_config_error("`:default` is not a valid timeout", nil, :timeout, default: Duration.new!(month: 1))
    end

    test "boolean truthy and falsy cannot be empty" do
      assert_config_error("`:truthy` cannot be empty", "1", :boolean, truthy: [])
      assert_config_error("`:falsy` cannot be empty", "1", :boolean, falsy: [])
    end
  end

  describe "option validation" do
    test "unknown options are rejected" do
      assert_config_error("unknown option `:bsae` (supported: `:base`, `:default`, `:or_raise`)", "1", :integer,
        bsae: 16
      )
    end

    test "multiple unknown options are listed together" do
      assert_config_error(
        "unknown options `:bsae`, `:dfault` (supported: `:base`, `:default`, `:or_raise`)",
        "1",
        :integer,
        bsae: 16,
        dfault: 1
      )
    end

    test "options are rejected for conversions without options" do
      assert_config_error("unknown option `:default` (supported: `:or_raise`)", "1", :elixir, default: 1)
    end

    test "options must be a keyword list" do
      assert_config_error("options must be a keyword list", "1", :integer, [:base])
    end

    test "composite options are routed to each layer" do
      assert [255, 15] == convert_as("ff;f", {:list, :integer}, delimiter: ";", base: 16)
      assert :red == convert_as(Base.encode16("RED"), {:base16, :atom}, case: :upper, downcase: true)
    end

    test "composite option errors name the requested type" do
      assert_config_error("invalid `:base` value (expected an integer in 2..36)", "1", {:list, :integer}, base: 40)
    end

    test "composite unknown options list both layers" do
      assert_config_error(
        "unknown option `:padding` \(supported: `:case`, `:base`, `:or_raise`\)",
        "ff",
        {:base16, :integer},
        padding: true
      )
    end

    test "options for the wrong layer are rejected" do
      assert_config_error(
        "unknown option `:base` (supported: `:case`, `:allowed`, `:downcase`, `:upcase`, `:or_raise`)",
        "ff",
        {:base16, :atom},
        base: 16
      )
    end

    test "default values are never included in messages" do
      for {type, default, message} <- [
            {:integer, "secret", "`:default` is not a valid base 10 integer"},
            {:float, "secret", "`:default` is not a valid float"},
            {:decimal, "secret", "`:default` is not a valid decimal"},
            {:timeout, "secret", "`:default` is not a valid timeout"}
          ] do
        error =
          assert_config_error(message, nil, type, default: default)

        refute Exception.message(error) =~ "secret"
      end

      error =
        assert_config_error("invalid `:default` value (expected integer or string)", nil, :integer, default: {:secret})

      refute Exception.message(error) =~ "secret"
    end

    test "option errors carry the failing key" do
      error =
        assert_config_error("`:truthy` and `:falsy` cannot both be provided", "1", :boolean,
          truthy: ["1"],
          falsy: ["0"]
        )

      assert error.key == [:truthy, :falsy]

      error =
        assert_config_error("unknown option `:bsae` (supported: `:base`, `:default`, `:or_raise`)", "1", :integer,
          bsae: 16
        )

      assert error.key == [:bsae]
    end
  end

  describe "or_raise" do
    test "raises with the provided message when the value is unset" do
      assert_raise RuntimeError, "PORT must be set", fn ->
        convert_as(nil, :integer, or_raise: "PORT must be set")
      end
    end

    test "is ignored when the value is set" do
      assert 42 == convert_as("42", :integer, or_raise: "PORT must be set")
    end

    test "applies to every primitive type" do
      for type <- [:integer, :float, :string, :atom, :boolean, :charlist] do
        assert_raise RuntimeError, "unset", fn ->
          convert_as(nil, type, or_raise: "unset")
        end
      end
    end

    test "raises for unset encoded conversions" do
      assert_raise RuntimeError, "need base64", fn ->
        convert_as(nil, {:base64, :integer}, or_raise: "need base64")
      end
    end

    test "raises for unset list conversions" do
      assert_raise RuntimeError, "need list", fn ->
        convert_as(nil, {:list, :integer}, or_raise: "need list")
      end
    end

    test "is mutually exclusive with :default" do
      assert_config_error(
        "`:default` and `:or_raise` cannot both be provided",
        nil,
        :integer,
        default: 1,
        or_raise: "no"
      )
    end

    test "is mutually exclusive with :default for encoded conversions" do
      assert_config_error(
        "`:default` and `:or_raise` cannot both be provided",
        nil,
        {:base64, :integer},
        default: 1,
        or_raise: "no"
      )
    end
  end

  describe "boolean then/else" do
    test "maps a true value to :then" do
      assert [:inet6] == convert_as("true", :boolean, then: [:inet6], else: [])
    end

    test "maps a false value to :else" do
      assert [] == convert_as("false", :boolean, then: [:inet6], else: [])
    end

    test "maps an unset value through the resolved default" do
      assert [] == convert_as(nil, :boolean, then: [:inet6], else: [])
      assert [:inet6] == convert_as(nil, :boolean, default: true, then: [:inet6], else: [])
    end

    test "honors :truthy and :falsy before mapping" do
      assert :yes == convert_as("oui", :boolean, truthy: ["oui"], then: :yes, else: :no)
      assert :no == convert_as("non", :boolean, truthy: ["oui"], then: :yes, else: :no)
    end

    test "requires both :then and :else" do
      assert_config_error("`:then` and `:else` must be provided together", "true", :boolean, then: :yes)
      assert_config_error("`:then` and `:else` must be provided together", "true", :boolean, else: :no)
    end

    test "maps list-element booleans" do
      assert [:on, :off, :on] == convert_as("1,0,1", {:list, :boolean}, then: :on, else: :off)
    end
  end

  describe "encoded defaults" do
    test "enc and {enc, :string} defaults are decoded strings, returned as-is" do
      for type <- [:base16, :base32, :hex32, :base64, :url_base64, {:base16, :string}, {:base64, :string}] do
        assert "RED" == convert_as(nil, type, default: "RED")
      end
    end

    test "enc and {enc, :string} defaults must be strings" do
      for type <- [:base16, {:base64, :string}] do
        assert_config_error("invalid `:default` value (expected string)", nil, type, default: 5)
      end
    end

    test "{enc, t} defaults are defaults for t" do
      assert 5 == convert_as(nil, {:base16, :integer}, default: 5)
      assert 255 == convert_as(nil, {:base16, :integer}, default: "ff", base: 16)
      assert 30_000 == convert_as(nil, {:base64, :timeout}, default: "30s")
      assert :red == convert_as(nil, {:base32, :atom}, default: "red", downcase: true, allowed: [:red])
    end

    test "{enc, t} defaults are validated by t" do
      assert_config_error("invalid `:default` value (expected integer or string)", nil, {:base16, :integer},
        default: 3.5
      )

      assert_config_error("`:default` is not a valid base 16 integer", "ff", {:base16, :integer},
        default: "zz",
        base: 16
      )
    end

    test "{enc, t} rejects :default when t has no defaults" do
      assert_config_error("unknown option `:default` (supported: `:or_raise`)", nil, {:base64, :elixir}, default: 1)

      assert_config_error("unknown option `:default` (supported: `:filter`, `:or_raise`)", nil, {:base64, :pem},
        default: "x"
      )
    end

    test "encoded defaults are not used when the value is set" do
      assert "RED" == convert_as(Base.encode16("RED"), :base16, default: "BLUE")
      assert 7 == convert_as(Base.encode16("7"), {:base16, :integer}, default: 5)
    end

    test "unset encoded values use the inner type's unset result" do
      assert nil == convert_as(nil, :base64)
      assert nil == convert_as(nil, {:base64, :integer})
      assert false == convert_as(nil, {:base64, :boolean})
      assert :infinity == convert_as(nil, {:base64, :timeout})
    end
  end

  describe "list defaults" do
    test "a string default is converted as if it were the value" do
      assert [1, 2, 3] == convert_as(nil, {:list, :integer}, default: "1,2,3")
      assert ["a", "b"] == convert_as(nil, :list, default: "a;b", delimiter: ";")
    end

    test "a list of strings is converted element by element" do
      assert [1, 2, 3] == convert_as(nil, {:list, :integer}, default: ["1", "2", "3"])
      assert [255] == convert_as(nil, {:list, :integer}, default: ["ff"], base: 16)
      assert ["1", "2"] == convert_as(nil, {:list, :string}, default: ["1", "2"])
    end

    test "other lists are prepared as element defaults" do
      assert [1, 2] == convert_as(nil, {:list, :integer}, default: [1, 2])
      assert [1.0, 2.5] == convert_as(nil, {:list, :float}, default: [1, 2.5])
      assert [:on] == convert_as(nil, {:list, :atom}, default: [:on], allowed: ~w[on off]a)
      assert [] == convert_as(nil, {:list, :integer}, default: [])
    end

    test "list defaults are not used when the value is set" do
      assert [7] == convert_as("7", {:list, :integer}, default: "1,2")
    end

    test "list defaults are not converted when the value is set" do
      assert [7] == convert_as("7", {:list, :integer}, default: ["x"])
    end

    test "list defaults are checked when the value is set" do
      assert_config_error("a list `:default` must contain only strings or no strings", "7", {:list, :integer},
        default: [1, "2"]
      )

      assert_raise Enviable.OptionError,
                   "could not convert environment variable \"VARNAME\" default[1] to type {:list, :integer}: invalid `:default` value (expected integer or string)",
                   fn -> convert_as("7", {:list, :integer}, default: [1, 2.5]) end
    end

    test "{:list, :string} is the same as :list" do
      assert ["1", "2"] == convert_as("1,2", {:list, :string})
      assert ["a", "b"] == convert_as(nil, {:list, :string}, default: "a,b")
    end

    test "string list defaults require string elements" do
      assert_raise Enviable.OptionError,
                   ~S|could not convert environment variable "VARNAME" default[0] to type list: invalid `:default` value (expected string)|,
                   fn -> convert_as(nil, :list, default: [1, 2, 3]) end
    end

    test "a non-string, non-list default is rejected" do
      assert_config_error("invalid `:default` value (expected string or a list)", nil, {:list, :integer}, default: 3)
    end

    test "default element conversion failures name the default element" do
      assert_raise Enviable.ConversionError,
                   ~S|could not convert environment variable "VARNAME" default[1] to type integer|,
                   fn -> convert_as(nil, {:list, :integer}, default: ["1", "x"]) end

      assert_raise Enviable.ConversionError,
                   ~S|could not convert environment variable "VARNAME" default[1] to type integer|,
                   fn -> convert_as(nil, {:list, :integer}, default: "1,x") end
    end

    test "value element conversion failures name the element" do
      error =
        assert_raise Enviable.ConversionError,
                     ~S(could not convert environment variable "VARNAME[1]" to type integer),
                     fn -> convert_as("1,x", {:list, :integer}) end

      assert error.index == 1
      assert error.source == :env
    end

    test "unset list without default" do
      assert nil == convert_as(nil, {:list, :integer})
    end
  end

  describe "error labels" do
    test "map-sourced values" do
      assert_raise Enviable.ConversionError,
                   ~S(could not convert environment map variable "PORT" to type integer),
                   fn ->
                     Conversion.convert_as(%Value{name: "PORT", value: "x", source: :map}, :integer, [])
                   end
    end
  end
end
