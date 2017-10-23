defmodule SrpcElliTest do
  use ExUnit.Case
  doctest SrpcElli

  test "greets the world" do
    assert SrpcElli.hello() == :world
  end
end
