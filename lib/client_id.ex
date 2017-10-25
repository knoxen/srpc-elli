defmodule SrpcElli.ClientId do

  @charset Application.get_env(:srpc_elli, :client_id_charset, :charset64)
  @bit_len Application.get_env(:srpc_elli, :client_id_bit_len, 128)
  
  use EntropyString, charset: @charset
  
  def generate do
    SrpcElli.ClientId.random_string(@bit_len)
  end

end
