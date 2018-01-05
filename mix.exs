defmodule SrpcElli.Mixfile do
  use Mix.Project

  def project do
    [app: :srpc_elli,
     version: "0.5.0",
     description: "Secure Remote Password Cryptor Elli Middleware",
     elixir: "~> 1.5",
     start_permanent: Mix.env == :prod,
     deps: deps(),
    ] ++ project(Mix.env)
  end

  defp project(:dev) do
    [erlc_options: [],
    ]
  end

  # CxTBD The erlc_options don't seem to "take". Pass --no-debug-info to mix compile for now.
  defp project(:prod) do
    [erlc_options: [:no_debug_info, :warnings_as_errors],
    ]
  end

  defp deps do
    [{:poison, "~> 3.1"},
     {:elli, git: "https://github.com/knoxen/elli.git", branch: "knoxen"},
    ] ++ deps(Mix.env)
  end

  defp deps(:dev) do
    [
     {:srpc_srv, path: "../../../erlang/srpc_srv"},
     {:srpc_lib, path: "../../../erlang/srpc_lib"},
    ]
  end

  defp deps(:prod) do
    [
     {:srpc_srv, path: "local/srpc_srv", compile: false},
     {:srpc_lib, path: "local/srpc_lib", compile: false},
    ]
  end
  
end
