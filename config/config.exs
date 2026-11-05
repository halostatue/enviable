import Config

if config_env() == :test do
  config :enviable, :paranoid, System.get_env("ENVIABLE_PARANOID") == "true"
end
