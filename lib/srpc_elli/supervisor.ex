defmodule SrpcElli.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(%{:srpc_handler => srpc_handler,
             :elli_port    => elli_port,
             :elli_stack   => elli_stack}) do
    
    :application.set_env(:srpc_elli, :srpc_handler, srpc_handler)

    elli_config = [{:mods, elli_stack}]
    elli_opts = [
      {:callback, :elli_middleware},
      {:callback_args, elli_config},
      {:port, elli_port},
      {:name, {:local, :elli}}
    ]

    children = [
      Supervisor.Spec.worker(:elli, [elli_opts])
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def init(_args), do: throw(:invalid_args)
  
end
