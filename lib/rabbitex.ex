defmodule Rabbitex do
  use Application
  use Hashex, [Rabbitex.Man.Pool, Rabbitex.Chan]
  require Logger

  @await_limit 50
  @await_delay 100

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Rabbitex.Worker, [arg1, arg2, arg3])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Rabbitex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defmodule Chan do
    defstruct pool: nil,
              conn: nil,
              chan: nil,
              number: nil,
              status: :ok,
              busy: false
  end

  ##############
  ### public ###
  ##############

  #
  # use init func in start of app
  #

  def init(opts, pool \\ :default_rabbitex_pool)
  def init( args = %{ username: username, 
                      password: password, 
                      host: host},
            pool ) when ( is_binary(username) and 
                          is_binary(password) and
                          (is_list(host) or is_binary(host)) and
                          is_atom(pool) ) do
    host = case is_binary(host) do
              true -> String.to_char_list(host)
              false -> host
            end
    virtual_host = case HashUtils.get(args, :virtual_host) do
            nil -> "/"
            some_bin when is_binary(some_bin) -> some_bin
          end
    heartbeat = case HashUtils.get(args, :heartbeat) do
            nil -> 1
            some_int when is_integer(some_int) -> some_int
          end
    size = case HashUtils.get(args, :size) do
            nil -> 1
            some_int when is_integer(some_int) -> some_int
          end
    case :erlang.whereis(pool) == :undefined do
      true -> %Rabbitex.Man.Pool{
                  poolname: pool,
                  username: username,
                  password: password,
                  host: host,
                  virtual_host: virtual_host,
                  heartbeat: heartbeat,
                  size: size,
                  channels: %{}} |> Rabbitex.Man.generate_new_pool
      false -> raise "Rabbitex : pool #{inspect pool} alreary exist!"
    end
  end

  #
  # here main func for usage
  #

  def send(term, exchange, routing_key \\ "", pool \\ :default_rabbitex_pool, attempt \\ 1)
  def send(_, _, _, pool, attempt) when (attempt > @await_limit) do
    {:error, "Rabbitex : no free channels to send in pool #{inspect pool}"}
  end
  def send(term, exchange, routing_key, pool, attempt) do
    case Rabbitex.Man.get_free_chan(pool) do
      :pool_not_exist -> raise "Rabbitex : pool #{inspect pool} does not exist!"
      :no ->  :timer.sleep(@await_delay)
              send(term, pool, attempt+1)
      chan -> case send_proc(chan, exchange, routing_key, term |> serialize) do
                :ok ->  Rabbitex.Man.set_free_chan(pool, chan)
                        :ok
                err ->  case is_valid_chan(chan) do
                          true -> Rabbitex.Man.set_free_chan(pool, chan)
                                  {:error, "Rabbitex : error #{inspect err}"}
                          false ->  Rabbitex.Man.reload_chan(pool, chan)
                                    :timer.sleep(@await_delay)
                                    send(term, pool, attempt+1)
                        end
              end
    end
  end

  ############
  ### priv ###
  ############

  defp serialize(term) do
    case HashUtils.is_hash?(term) do
      true -> HashUtils.to_map(term) |> Exutils.prepare_to_jsonify |> Jazz.encode!
      false -> 
        case is_binary(term) do
          true -> term
          false -> raise "Rabbitex : wrong term, can't serialize it."
        end
    end
  end

  defp send_proc(%Chan{chan: chan}, exchange, routing_key, bin) do
    case Retry.run(%{sleep: 50, tries: 3},
        fn() -> :ok = Exrabbit.Utils.publish(chan, exchange, routing_key, bin, :wait_confirmation) end) do
      {:ok, :ok} -> :ok
      err ->  err
    end
  end
  
  defp is_valid_chan(%Chan{chan: chan}) do
    :erlang.process_info(chan) != :undefined
  end

  #
  # TODO
  #
  #  defp is_valid_chan(%Chan{chan: chan, conn: conn}) do
  #    (:erlang.process_info(chan) != :undefined) and (:erlang.process_info(conn) != :undefined)
  #  end
  #
  #


end

