defmodule SrpcElli.Application do
  @moduledoc false

  use Application

  def start(_type, args) do
    Process.register self(), SrpcElli.Application
    SrpcElli.Supervisor.start_link(args)
  end

end
