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
    :ok =
      srpc(:file)
      |> File.read!
      |> :srpc_lib.init

    Application.put_env(:srpc_srv, :srpc_handler, srpc(:handler))
    
    elli_config = [{:mods, elli_stack()}]
    elli_opts = [
      {:callback, :elli_middleware},
      {:callback_args, elli_config},
      {:port, elli(:port)},
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

  def init(_args), do: throw(:invalid_args)

  defp param(mod, key) do
    value =
      :srpc_elli
      |> Application.get_env(mod)
      |> Keyword.get(key)

    unless value do
      raise SrpcElli.Error, message: "SrpcElli: Required #{mod} configuration for #{key} missing"
    end
    value
  end

  defp srpc(param), do: param(:srpc, param)
  
  defp elli(param), do: param(:elli, param)

  defp elli_stack do
    stack = elli(:stack)
    # Ensure each module in elli_stack is actually an elli_handler
    stack
    |> Keyword.keys
    |> Enum.each(fn(mod) -> mod |> validate_elli_handler end)

    stack
  end

  defp validate_elli_handler(mod) do
    funs = mod.__info__(:functions)
    unless funs |> Enum.member?({:handle, 2}) and funs |> Enum.member?({:handle_event, 3}) do
      throw "Invalid module in elli_stack: #{mod} does not provide elli_handler behaviour"
    end
  end
  
end
