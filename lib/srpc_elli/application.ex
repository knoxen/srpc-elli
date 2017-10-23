defmodule SrpcElli.Application do
  @moduledoc false

  @elli_port 4000
  
  use Application

  import Supervisor.Spec

  def start(_type, args) do
    IO.puts "start args = #{inspect args}"
    
    elli_config =
      [{:mods,
        [{SrpcElli, []},
         {Intf.ElliHandler, [] }
        ]}
      ]

    elli_opts =
      [{:callback, :elli_middleware},
       {:callback_args, elli_config},
       {:port, @elli_port}
      ]

    children = [
      worker(:elli, [elli_opts])
    ]

    opts = [name: SrpcElli.Supervisor,
            strategy: :one_for_one,
            ]
            
    Supervisor.start_link(children, opts)
  end
end
