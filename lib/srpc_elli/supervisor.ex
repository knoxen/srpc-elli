defmodule SrpcElli.Supervisor do
  @moduledoc false

  use Supervisor

  def child_spec([]) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, []}, type: :supervisor}
  end

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    case SrpcElli.AppConfig.process() do
      {:ok, {port, stack}} ->
        start_elli(port, stack)

      {:error, msg} ->
        raise SrpcElli.Error, message: msg
    end
  end

  def init(_args), do: throw(:invalid_args)

  defp start_elli(port, stack) do
    elli_config = [{:mods, stack}]

    elli_opts = [
      {:callback, :elli_middleware},
      {:callback_args, elli_config},
      {:port, port},
      {:min_acceptors, 10},
      {:name, {:local, :elli}}
    ]

    children = [
      %{
        id: Elli,
        start: {:elli, :start_link, [elli_opts]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
