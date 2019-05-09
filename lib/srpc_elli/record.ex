defmodule SrpcElli.Record do
  import Record, only: [defrecord: 2, extract: 2]
  defrecord :req, extract(:req, from_lib: "elli/include/elli.hrl")
end
