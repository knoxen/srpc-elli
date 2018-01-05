defmodule SrpcElli.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(%{:srpc_handler => srpc_handler,
             :elli_port    => elli_port,
             :elli_stack   => elli_stack}) do

    # Ensure each module in elli_stack is actually an elli_handler
    try do
      elli_stack
      |> Keyword.keys
      |> Enum.each(fn(mod) ->
        unless mod.__info__(:exports) |> valid_elli_handler do
          throw "Invalid module in elli_stack: #{mod} does not provide elli_handler behaviour"
        end
      end)
    rescue
      _ ->
        throw "Invalid module in elli_stack: #{elli_stack |> Keyword.keys |> inspect}"
    end
    
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

  defp valid_elli_handler(exports) do
    # :erlang.function_exported(mod, :handle, 2) and 
    # :erlang.function_exported(mod, :handle_event, 3)
    exports |> Enum.member?({:handle, 2}) and
    exports |> Enum.member?({:handle_event, 3})
  end

end
