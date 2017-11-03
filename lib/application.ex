defmodule SrpcElli.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # Ensure SRPC handler is avaliable for later use
    required_config(:srpc_handler)

    # Prepend SRPC elli handler
    elli_handlers =  [{SrpcElli.ElliHandler, []}] ++ required_config(:elli_handlers)

    elli_config = [{:mods, elli_handlers}]

    port = required_config(:port)
    elli_opts =
      [{:callback, :elli_middleware},
       {:callback_args, elli_config},
       {:port, port}
      ]

    children = [
      Supervisor.Spec.worker(:elli, [elli_opts])
    ]

    opts = [name: SrpcElli.Supervisor,
            strategy: :one_for_one,
            ]
            
    Supervisor.start_link(children, opts)
  end

  defp required_config(config) do
    case Application.get_env(:srpc_elli, config) do
      nil ->
        raise ":srpc_elli requires config for #{config}"
      value ->
        value
    end
  end
  
end
