defmodule Alchemy.Cogs.CommandHandler do
  require Logger
  use GenServer
  @moduledoc false


  def add_commands(commands) do
    GenServer.cast(Commands, {:add_commands, commands})
  end

  def set_prefix(new) do
    GenServer.cast(Commands, {:set_prefix, new})
  end

  def dispatch(message) do
    GenServer.cast(Commands, {:dispatch, message})
  end


  ### Server ###

  def start_link do
    GenServer.start_link(__MODULE__, %{prefix: "!"}, name: Commands)
  end

  def handle_call(_, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:set_prefix, prefix}, state) do
    {:noreply, %{state | prefix: prefix}}
  end

  def handle_cast({:add_commands, commands}, state) do
    Logger.debug "adding commands"
    {:noreply, Map.merge(state, commands)}
  end

  def handle_cast({:dispatch, message}, state) do
    Task.start(fn -> dispatch(message, state) end)
    {:noreply, state}
  end


  defp take_string([]), do: ""
  defp take_string([head | tail]), do: [head | take_string(tail)]
  defp dispatch(message, state) do
     prefix = state.prefix
     [command |[rest|_]] = message.content
                      |> String.split([prefix, " "], parts: 3)
                      |> Enum.concat(["", ""])
                      |> Enum.drop(1)
     command = String.to_atom(command)
     case state[command] do
       {mod, arity} ->
         run_command(mod, command, arity, &String.split(&1), message, rest)
       {mod, arity, parser} ->
         run_command(mod, command, arity, parser, message, rest)
         _ -> nil
     end
  end

  defp run_command(mod, method, arity, parser, message, content) do
    args = Enum.take(parser.(content), arity)
    apply(mod, method, [message | args])
  end
end
