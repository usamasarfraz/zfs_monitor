
defmodule ZfsMonitor do
  @moduledoc """
  Monitor OpenZFS pools using the zpool command.
  """

  defp zpool do
    System.find_executable("zpool") || "/usr/sbin/zpool"
  end

  def status(pool \\ "rpool") do
    execute(["status", "-P", pool])
  end

  def health(pool \\ "rpool") do
    case status(pool) do
      {:ok, output} ->
        state =
          case Regex.run(~r/state:\s+(\w+)/, output) do
            [_, value] -> value
            _ -> "UNKNOWN"
          end

        {:ok,
         %{
           pool: pool,
           state: state,
           healthy: state == "ONLINE",
           output: output
         }}

      error ->
        error
    end
  end

  def list do
    execute([
      "list",
      "-H",
      "-p",
      "-o",
      "name,size,alloc,free,cap,health"
    ])
    |> parse_list()
  end

  defp parse_list({:ok, output}) do
    pools =
      output
      |> String.split("\n", trim: true)
      |> Enum.map(fn line ->
        [name, size, alloc, free, cap, health] =
          String.split(line, "\t")

        %{
          name: name,
          size: String.to_integer(size),
          allocated: String.to_integer(alloc),
          free: String.to_integer(free),
          capacity: cap,
          health: health
        }
      end)

    {:ok, pools}
  end

  defp parse_list(error), do: error

  defp execute(args) do
    case System.cmd(zpool(), args, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, String.trim(output)}

      {output, code} ->
        {:error,
         %{
           exit_code: code,
           message: String.trim(output)
         }}
    end
  end


  
  def run(command, args \\ [], _opts \\ []) do
    executable = System.find_executable(command)

    if executable do
      try do
        case System.cmd(
              executable,
              args,
              stderr_to_stdout: true
            ) do
          {output, 0} ->
            {:ok, String.trim(output)}

          {output, code} ->
            {:error,
            %{
              exit_code: code,
              output: String.trim(output)
            }}
        end
      rescue
        error ->
          {:error, Exception.message(error)}
      end
    else
      {:error, :command_not_found}
    end
  end
end
