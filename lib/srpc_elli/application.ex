defmodule SrpcElli.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    Process.register self(), SrpcElli.Application
    SrpcElli.Supervisor.start_link()
  end

end
