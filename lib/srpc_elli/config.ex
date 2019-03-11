defmodule SrpcElli.Config do
  @moduledoc false

  def process() do
    case process_app_srpc_config() do
      :ok ->
        process_app_elli_config()

      error ->
        error
    end
  end

  defp process_app_srpc_config() do
    :srpc
    |> app_config(:server_file)
    |> case do
      {:ok, server_file} ->
        case set_server_config(server_file) do
          :ok ->
            set_srpc_handler()

          error ->
            error
        end

      error ->
        error
    end
  end

  defp set_server_config(file) do
    file
    |> File.read!()
    |> :srpc_lib.srpc_parse_config()
    |> case do
      {:ok, %{:srpc_type => 0} = config} ->
        Application.put_env(:srpc_srv, :server_config, config)
        :ok

      {:ok, %{:srpc_type => 1}} ->
        {:error, "SrpcElli: SRPC configuration file is for client"}

      error ->
        error
    end
  end

  defp set_srpc_handler() do
    :srpc
    |> app_config(:handler)
    |> case do
      {:ok, srpc_handler} ->
        Application.put_env(:srpc_srv, :srpc_handler, srpc_handler)
        :ok

      error ->
        error
    end
  end

  defp process_app_elli_config() do
    case elli_stack() do
      {:ok, stack} ->
        :elli
        |> app_config(:port)
        |> case do
          {:ok, port} ->
            {:ok, {port, stack}}

          error ->
            error
        end

      error ->
        error
    end
  end

  defp elli_stack() do
    :elli
    |> app_config(:stack)
    |> case do
      {:ok, stack} ->
        stack
        |> Keyword.keys()
        |> Enum.reduce(
          {true, ""},
          fn mod, {valid, err_msg} ->
            if valid, do: validate_elli_handler(mod), else: {valid, err_msg}
          end
        )
        |> case do
          {true, _} ->
            {:ok, stack}

          error ->
            error
        end

      error ->
        error
    end
  end

  defp validate_elli_handler(mod) do
    funs = mod.__info__(:functions)

    has_handle_fn = Enum.member?(funs, {:handle, 2})
    has_handle_event_fn = Enum.member?(funs, {:handle_event, 3})

    if has_handle_fn and has_handle_event_fn,
      do: {true, ""},
      else:
        {false, "Invalid module in elli_stack: #{mod} does not provide elli_handler behaviour"}
  end

  defp app_config(mod, option) do
    :srpc_elli
    |> Application.get_env(mod)
    |> Keyword.get(option)
    |> case do
      nil ->
        {:error, "SrpcElli: Required #{mod} configuration for #{option} missing"}

      value ->
        {:ok, value}
    end
  end
end
