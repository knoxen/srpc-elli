defmodule SrpcElli.Mixfile do
  use Mix.Project

  def project do
    [
      app: :srpc_elli,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      erlc_options: [:no_debug_info],
      deps: deps(),
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:sasl, :logger],
      mod: {SrpcElli.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elli,     git: "https://github.com/knoxen/elli.git", branch: "knoxen"},
      {:srpc_srv, path: "../../../erlang/srpc_srv"},
      {:srpc_lib, path: "../../../erlang/srpc_lib"},
      # {:srpc_srv, path: "local/srpc_srv", compile: false},
      # {:srpc_lib, path: "local/srpc_lib", compile: false},
      {:entropy_string, "~> 1.0"},
      {:poison, "~> 3.1"}
    ]
  end
end
