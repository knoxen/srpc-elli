defmodule SrpcElli.Mixfile do
  use Mix.Project

  def project do
    [
      app: :srpc_elli,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {SrpcElli.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elli,     git: "git@github.com:knoxen/elli.git", branch: "knoxen"},
      {:srpc_srv, git: "git@github.com:knoxen/srpc-srv.git", tag: "0.15.0"},
      {:srpc_lib, git: "git@github.com:knoxen/srpc-lib.git", tag: "0.14.0"},
      {:entropy_string, "~> 1.0"},
      {:poison, "~> 3.1"}
    ]
  end
end
