defmodule SrpcElli.ElliHandler do
  @moduledoc false

  @behaviour :elli_handler

  require SrpcElli.Record
  alias SrpcElli.Record, as: Elli

  alias :srpc_srv, as: Srpc
  alias :elli_request, as: Request

  ## ===============================================================================================
  ##
  ##  Preprocess Request
  ##
  ## ===============================================================================================
  def preprocess(req, _args) do
    time_stamp(:srpc_start)

    case {Request.method(req), Request.path(req)} do
      {:POST, []} ->
        req
        |> Request.body()
        |> Srpc.parse_packet()
        |> srpc_preprocess(req)

      _ ->
        respond({:error, "Invalid request: Only SRPC POST to / are processed"})
    end
  end

  ## ===============================================================================================
  ##
  ##  SRPC Preprocessing
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ##  Preprocess lib exchange
  ## -----------------------------------------------------------------------------------------------
  defp srpc_preprocess({:lib_exchange, _data}, req) do
    :erlang.put(:req_type, :lib_exchange)
    req
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Preprocess srpc action
  ## -----------------------------------------------------------------------------------------------
  defp srpc_preprocess({:srpc_action, client_conn, _data}, req) do
    :erlang.put(:req_type, :srpc_action)
    :erlang.put(:client_conn, client_conn)
    req
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Preprocess app request
  ## -----------------------------------------------------------------------------------------------
  defp srpc_preprocess({:app_request, client_conn, data}, req) do
    :erlang.put(:req_type, :app_request)
    :erlang.put(:client_conn, client_conn)

    case Srpc.unwrap(client_conn, data) do
      {:ok,
       {nonce,
        <<app_map_len::size(16), app_map_data::binary-size(app_map_len), app_body::binary>>}} ->
        :erlang.put(:nonce, nonce)

        app_map_data
        |> Poison.decode()
        |> case do
          {:ok, app_map} ->
            if Map.has_key?(app_map, "proxy") do
              :erlang.put(:srpc_proxy, app_map["proxy"])
            end

            build_app_req(app_map, app_body, req)

          :error ->
            respond({:error, "Invalid app map in request packet"})
        end

      {:ok, _data} ->
        respond({:error, "Invalid data in request packet"})

      other ->
        respond(other)
    end
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Preprocess invalid and error request
  ## -----------------------------------------------------------------------------------------------
  defp srpc_preprocess(other, _req), do: respond(other)

  ## -----------------------------------------------------------------------------------------------
  ##   Build app request from app map
  ## -----------------------------------------------------------------------------------------------
  defp build_app_req(app_map, app_body, req) do
    app_method = :erlang.binary_to_atom(app_map["method"], :utf8)
    app_raw_path = app_map["path"]
    app_path = split_path(app_raw_path)
    app_args = split_query_string(app_map["query"])

    headers = Request.headers(req)
    headers = :proplists.delete("Content-Type", headers)
    headers = :proplists.delete("Content-Length", headers)

    headers =
      :lists.append(
        headers,
        [{"Content-Length", app_body |> byte_size |> Integer.to_string()}]
      )

    app_headers = Enum.map(app_map["headers"], fn e -> e end) ++ headers

    req
    |> Elli.req(method: app_method)
    |> Elli.req(raw_path: app_raw_path)
    |> Elli.req(path: app_path)
    |> Elli.req(args: app_args)
    |> Elli.req(headers: app_headers)
    |> Elli.req(body: app_body)
  end

  ## ===============================================================================================
  ##
  ##  Handle Request
  ##
  ## ===============================================================================================
  def handle({_code, _hdrs, _data} = resp, _args), do: resp

  def handle(req, _args) do
    :req_type
    |> :erlang.get()
    |> handle_req(req)
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Handle lib exchange
  ## -----------------------------------------------------------------------------------------------
  defp handle_req(:lib_exchange, req) do
    {:lib_exchange, req_data} =
      req
      |> Request.body()
      |> Srpc.parse_packet()

    :srpc_srv
    |> Application.get_env(:server_config)
    |> Srpc.lib_exchange(req_data)
    |> case do
      {:ok, resp_data} ->
        :erlang.put(:srpc_action, :lib_exchange)
        respond({:data, resp_data})

      not_ok ->
        respond(not_ok)
    end
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Handle srpc action
  ## -----------------------------------------------------------------------------------------------
  defp handle_req(:srpc_action, req) do
    {:srpc_action, client_conn, req_data} =
      req
      |> Request.body()
      |> Srpc.parse_packet()

    case Srpc.srpc_action(client_conn, req_data) do
      {_srpc_action, {:invalid, _} = invalid} ->
        respond(invalid)

      {srpc_action, result} ->
        :erlang.put(:srpc_action, srpc_action)
        respond(result)
    end
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Handle app request
  ## -----------------------------------------------------------------------------------------------
  defp handle_req(:app_request, req) do
    :erlang.put(:app_info, {Request.method(req), Request.raw_path(req)})
    time_stamp(:app_start)
    :ignore
  end

  ## ===============================================================================================
  ##
  ## Postprocess
  ##
  ## ===============================================================================================
  def postprocess(req, {code, data}, config), do: postprocess(req, {code, [], data}, config)

  def postprocess(req, {:ok, hdrs, data}, []), do: postprocess(req, {200, hdrs, data}, [])

  def postprocess(_req, {code, _hdrs, data} = resp, []) do
    case :erlang.get(:req_type) do
      :app_request ->
        len = :erlang.byte_size(data)
        app_end(code, len)
        postprocess_app_request(resp)

      _ ->
        respond(resp)
    end
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Postprocess app request
  ## -----------------------------------------------------------------------------------------------
  def postprocess_app_request({code, headers, data}) do
    resp_headers = List.foldl(headers, %{}, fn {k, v}, map -> Map.put(map, k, v) end)

    info_data = %{"respCode" => code, "headers" => resp_headers} |> Poison.encode!()
    info_len = :erlang.byte_size(info_data)

    nonce =
      case :erlang.get(:nonce) do
        :undefined -> ""
        value -> value
      end

    packet = <<info_len::size(16), info_data::binary, data::binary>>

    respond(Srpc.wrap(:erlang.get(:client_conn), nonce, packet))
  end

  ## ===============================================================================================
  ##
  ##  Events
  ##
  ## ===============================================================================================
  def handle_event(_event, _data, _args) do
    :ok
  end

  ## ===============================================================================================
  ##
  ##  Respond
  ##
  ## ===============================================================================================
  defp respond({:ok, data}) do
    respond({:data, data})
  end

  defp respond({:data, data}) do
    time_stamp(:srpc_end)
    {200, resp_headers(:data), data}
  end

  defp respond({:error, reason}) do
    :erlang.put(:reason_fail, "Bad Request: #{inspect(reason)}")
    time_stamp(:srpc_end)
    {400, resp_headers(:text), "Bad Request"}
  end

  defp respond({:invalid, reason}) do
    :erlang.put(:reason_fail, "Invalid Request: #{inspect(reason)}")
    :erlang.put(:app_info, :undefined)
    :erlang.put(:srpc_action, :invalid)
    time_stamp(:srpc_end)
    {403, resp_headers(:text), "Forbidden"}
  end

  defp respond({_code, _hdrs, _data} = resp) do
    time_stamp(:srpc_end)
    resp
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Response Headers
  ## -----------------------------------------------------------------------------------------------
  defp resp_headers(:data) do
    resp_headers("application/octet-stream")
  end

  defp resp_headers(:text) do
    resp_headers("text/plain")
  end

  defp resp_headers(content_type) do
    [
      {"X-Knoxen-Server", "Knoxen Elli/0.10.0"},
      {"Connection", "close"},
      {"Content-Type", content_type}
    ]
  end

  ## -----------------------------------------------------------------------------------------------
  ##
  ## -----------------------------------------------------------------------------------------------
  defp time_stamp(marker) do
    :erlang.put({:time, marker}, :erlang.monotonic_time())
  end

  ## -----------------------------------------------------------------------------------------------
  ##
  ## -----------------------------------------------------------------------------------------------
  defp app_end(code, len) do
    case :erlang.get(:app_info) do
      {method, path} ->
        :erlang.put(:app_info, {method, path, code, len})
        time_stamp(:app_end)

      :undefined ->
        :ok
    end
  end

  ## -----------------------------------------------------------------------------------------------
  ##
  ## -----------------------------------------------------------------------------------------------
  defp split_path(path) do
    for segment <- :binary.split(path, "/", [:global]), segment != "", do: segment
  end

  ## -----------------------------------------------------------------------------------------------
  ##
  ## -----------------------------------------------------------------------------------------------
  defp split_query_string(qs) do
    qs
    |> :binary.split("&", [:global, :trim])
    |> split_terms
    |> kv_terms
  end

  defp split_terms(terms), do: for(term <- terms, do: :binary.split(term, "="))

  defp kv_terms(kvs), do: for(kv <- kvs, do: term_kv(kv))

  defp term_kv([key, value]), do: {key, value}
  defp term_kv([key]), do: {key, true}
end
