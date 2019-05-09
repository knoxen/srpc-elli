defmodule SrpcElli.AppConfig do
  @moduledoc false

  def process() do
    case app_srpc_config() do
      :ok ->
        app_elli_config()

      error ->
        error
    end
  end

  defp app_srpc_config() do
    srpc_config_file()
    |> case do
      {:ok, file} ->
        file
        |> process_config_file()
        |> case do
             :ok ->
               set_srpc_handler()

             error ->
               error
           end

         error ->
           error
       end
  end

  defp process_config_file(file) do
    file
    |> File.read!()
    |> :srpc_lib.parse_srpc_config()
    |> case do
      {:ok, %{:type => 0} = config} ->
        Application.put_env(:srpc_srv, :server_config, config)
        :ok

      {:ok, %{:srpc_type => 1}} ->
        {:error, "SrpcElli: SRPC configuration file is for client, not server"}

      error ->
        error
    end
  end

  defp srpc_config_file() do
    :srpc
    |> app_config(:server_file)
    |> case do
      {:ok, file} ->
        app_file(file)

      error ->
        error
    end
  end

  defp app_file(file) do
    :srpc
    |> app_config(:app_name)
    |> case do
      {:ok, app_name} ->
        {:ok,
         app_name
         |> Application.app_dir()
         |> Kernel.<>("/")
         |> Kernel.<>(file)}

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

  defp app_elli_config() do
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
