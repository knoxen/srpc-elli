defmodule SrpcElli do
  @moduledoc """
  CxTBD Documentation for SrpcElli.
  """

  @behaviour :elli_handler

  require SrpcElli.Record
  alias SrpcElli.Record, as: Elli

  alias :srpc_srv, as: Srpc
  alias :elli_request, as: Request

  require Logger

  ##
  ## Preprocess
  ##
  def preprocess(req, _args) do
    IO.puts "preprocess req = #{inspect req}\n"

    time_stamp(:srpc_start)
    case Request.method(req) do
      :POST ->
        preprocess_post(req, Request.path(req))
      _ ->
        respond {:error, "Invalid request: Only SRPC POST accepted"}
    end
  end

  ##
  ## Preprocess POST
  ##
  defp preprocess_post(req, []) do
    req
    |> Request.body
    |> Srpc.parse_packet
    |> preprocess_srpc(req)
  end

  defp preprocess_post(_req, _path) do
    respond {:error, "Invalid request: Only SRPC POST to / accepted"}
  end

  ##
  ## Preprocess SRPC
  ##
  defp preprocess_srpc({:lib_exchange, _data}, req) do
    :erlang.put(:req_type, :lib_echange)
    req
  end

  defp preprocess_srpc({:srpc_action, client_info, _data}, req) do
    :erlang.put(:req_type, :srpc_action)
    :erlang.put(:client_info, client_info)
    req
  end

  defp preprocess_srpc({:app_request, client_info, data}, req) do
    :erlang.put(:req_type, :app_request)
    :erlang.put(:client_info, client_info)
    case preprocess_app_req(client_info, data, req) do
      {:ok, app_req} ->
        app_req;
      {:invalid, reason} ->
        peer = Request.peer(req)
        respond({:invalid, peer, reason})
      error ->
        respond(error)
    end
  end

  defp preprocess_srpc({:invalid, reason}, req) do
    peer = Request.peer(req)
    respond({:invalid, peer, reason})
  end

  ##
  ## Preprocess App Request
  ##
  defp preprocess_app_req(client_info, data, req) do
    case Srpc.decrypt(:origin_client, client_info, data) do
      {:ok, {nonce,
            << app_map_len  :: size(16),
               app_map_data :: binary - size(app_map_len),
               app_body     :: binary >>}} ->
        :erlang.put(:nonce, nonce)
        app_map = Poison.decode(app_map_data)
        if Map.has_key?(app_map, "proxy") do
          :erlang.put(:srpc_proxy, app_map["proxy"])
        end
        {:ok, build_app_req(app_map, app_body, req)}
      {:ok, _data} ->
        {:error, "Invalid data in request packet"}
      result ->
        result
    end
  end

  defp build_app_req(app_map, app_body, req) do
    headers = Request.headers(req)
    headers = :proplists.delete("Content-Type", headers)
    headers = :proplists.delete("Content-Length", headers)
    headers = :lists.append(headers, [{"Content-Length", :erlang.size(app_body)}])

    app_headers = app_map["headers"] || [] ++ headers
    app_path = split_path(app_map["path"])
    app_qs = split_query_string(app_map["query"]) || ""

    SrpcElli.Record.req(req)
    |> Elli.req(method: app_map["method"])
    |> Elli.req(path: app_path)
    |> Elli.req(args: app_qs)
    |> Elli.req(headers: app_headers)
    |> Elli.req(body: app_body)
  end

  ##
  ## Handle
  ##
  def handle({_code, _hdrs, _data} = resp, _args), do: resp

  def handle(req, _args), do: :erlang.get(:req_type) |> handle_req_type(req)

  defp handle_req_type(:lib_exchange, req) do
    client_id()
    |> Srpc.lib_exchange(Request.body(req))
    |> case do
         {:ok, exchange_data} ->
           :erlang.put(:srpc_action, :lib_exchange)
           respond({:data, exchange_data})
         {:invalid, reason} ->
           respond_invalid(req, reason)
         {:error, _} = error ->
           error
       end
  end

  defp handle_req_type(:srpc_action, req) do
    case Srpc.srpc_action(Request.body(req)) do
      {_srpc_action, {:invalid, reason}} ->
        respond_invalid(req, reason)
      {srpc_action, result} ->
        :erlang.put(:srpc_action, srpc_action)
        respond(result)
    end
  end

  defp handle_req_type(:app_request, req) do
    :erlang.put(:app_info, {Request.method(req), Request.raw_path(req)})
    # The app handles the actual request
    :ignore
  end

  defp handle_req_type(_, _req) do
    :ignore
  end

  ##
  ## Postprocess
  ##
  def postprocess(req, {code, data}, config), do: postprocess(req, {code, [], data}, config)

  def postprocess(req, {:ok, hdrs, data}, config), do: postprocess(req, {200, hdrs, data}, config)

  def postprocess(req, {code, _hdrs, data} = resp, _config) do
    case :erlang.get(:req_type) do
      :app_request ->
        app_end(req, code, data)

        case :erlang.get(:srpc_proxy) do
          :undefined -> code
          _ -> 200
        end
        |> case do
             200 -> postprocess_app_request(resp)
             _ -> respond(resp)
           end
      _ -> respond(resp)
    end
  end

  def postprocess_app_request({code, headers, data}) do
    resp_headers = List.foldl(fn({k,v}, map) -> Map.put(map, k, v) end, %{}, headers)
    info_map = %{"respCode" => code, "headers" => resp_headers}

    info_data = Poison.encode(info_map)
    info_len = :erlang.byte_size(info_data)
    nonce = :erlang.get(:nonce)
    packet = << info_len :: size(16), info_data :: binary, data :: binary >>
    client_info = :erlang.get(:client_info)
    respond(Srpc.encrypt(:origin_server, client_info, nonce, packet))
  end

  ##
  ## Events
  ##
  def handle_event(_event, _data, _args) do
    :ok
  end

  ##
  ## Respond
  ##
  defp respond({:ok, data}) do
    respond({:data, data})
  end

  defp respond({:data, data}) do
    time_stamp(:srpc_end)
    {200, resp_headers(:data), data}
  end

  defp respond({:error, reason}) do
    time_stamp(:srpc_end)
    Logger.warn("Bad Request: #{reason}")
    {400, resp_headers(:text), "Bad Request"}
  end

  defp respond({:invalid, peer, reason}) do
    time_stamp(:srpc_end)
    :erlang.put(:app_info, :undefined)
    :erlang.put(:srpc_action, :invalid)
    Logger.warn "#{peer} #{reason}"
    {403, resp_headers(:text), "Forbidden"}
  end

  # CxDebug ??
  defp respond({_code, _hdrs, _data} = resp) do
    Logger.error "CxInc Should this call to SrpcElli.respond occur? resp = #{inspect resp}"
    resp
  end

  ##
  ## Respond to invalid SRPC request
  ##
  defp respond_invalid(req, {:invalid, reason}) do
    respond_invalid(req, reason)
  end

  defp respond_invalid(req, reason) do
    respond({:invalid, Request.peer(req), reason})
  end

  ##
  ## Response Headers
  ##
  defp resp_headers(:data) do
    resp_headers("application/octet-stream")
  end

  defp resp_headers(:text) do
    resp_headers("text/plain")
  end

  defp resp_headers(content_type) do
    [{"X-Knoxen-Server", "Knoxen Elli/0.10.0"},
     {"Connection", "close"},
     {"Content-Type", content_type},
    ]
  end

  ##
  ##
  ##
  defp client_id(), do: "CxInc client id"
  
  ##
  ##
  ##
  defp time_stamp(marker) do
    :erlang.put({:time, marker}, :erlang.monotonic_time(:micro_seconds))
  end

  defp app_end(req, code, data) do
    time_stamp(:app_end)
    method = Request.method(req)
    path = Request.raw_path(req)
    length = :erlang.byte_size(data)
    :erlang.put(:app_info, {method, path, code, length})
  end

  defp split_path(path) do
    for segment <- :binary.split(path, "/", [:global]), segment != "", do: segment
  end

  defp split_query_string(qs) do
    qs
    |> :binary.split("&", [:global, :trim])
    |> split_terms
    |> kv_terms
  end

  defp split_terms(terms), do: for term <- terms, do: :binary.split(term, "=")

  defp term_kv([key, value]), do: {key, value}
  defp term_kv([key]), do: {key, :true}

  defp kv_terms(kvs), do: for kv <- kvs, do: term_kv(kv)

end
