use Mix.Config

config :srpc_elli,
  ## Required
  port: 4444,
  srpc_handler: Dummy.SrpcHandler,
  elli_handlers: [
    {Dummy.ElliHandler, []}
  ]
