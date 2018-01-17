defmodule SrpcElli.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    # Ensure each module in elli_stack is actually an elli_handler
    elli_stack = Application.get_env :srpc_elli, :stack
    elli_stack
    |> Keyword.keys
    |> Enum.each(fn(mod) -> mod |> validate_elli_handler end)

    elli_port = Application.get_env :srpc_elli, :port
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

  defp validate_elli_handler(mod) do
    exports = mod.__info__(:exports)
    unless exports |> Enum.member?({:handle, 2}) and exports |> Enum.member?({:handle_event, 3}) do
      throw "Invalid module in elli_stack: #{mod} does not provide elli_handler behaviour"
    end
      
  end

end
