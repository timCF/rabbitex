defmodule Rabbitex.Man do
	use ExActor.GenServer
	require Logger
	@timeout :timer.minutes(1)

	defmodule Pool do
		@derive [HashUtils]
		defstruct 	poolname: nil,
					username: "",
					password: "",
					host: '',
					virtual_host: "",
					heartbeat: 1,
					size: 1,
					channels: %{},
					stamp: 0
	end

	##############
	### public ###
	##############

	def generate_new_pool(pool = %Pool{poolname: poolname}) do
		:ok = :supervisor.start_child(Rabbitex.Supervisor, Supervisor.Spec.worker(Rabbitex.Man, [pool], [id: poolname])) |> elem(0)
	end
	def get_free_chan(pname) do
		case :erlang.whereis(pname) do
			:undefined -> :pool_not_exist
			_ -> Rabbitex.Man.get_free_chan_proc(pname)
		end
	end

	definit(state = %Pool{poolname: poolname}) do
		:erlang.register(poolname, self)
		Logger.info "Rabbitex : init #{inspect poolname} pool."
		{:ok, state, 0}
	end
	defcall get_free_chan_proc, state: state = %Pool{channels: channels} do
		case HashUtils.values(channels)
				|> Enum.filter( fn(%Rabbitex.Chan{status: status, busy: busy}) -> (status == :ok) and (busy == false) end ) do
			[] -> {	:reply, :no, state |> refresh_state, @timeout }
			[chan = %Rabbitex.Chan{number: num} | _rest] -> 
				{
					:reply,
					chan,
					HashUtils.set(state, [:channels, num, :busy], true) |> refresh_state,
					@timeout
				}
		end
	end
	defcall set_free_chan(%Rabbitex.Chan{number: num}), state: state do
		{
			:reply,
			:ok,
			HashUtils.set(state, [:channels, num, :busy], false) |> refresh_state, 
			@timeout
		}
	end
	defcall reload_chan(%Rabbitex.Chan{number: num}), state: state do
		{
			:reply,
			:ok,
			HashUtils.set(state, [:channels, num], create_chan(num, state)) |> refresh_state, 
			@timeout
		}
	end
	definfo :timeout, state: state do
		{:noreply, state |> refresh_state, @timeout}
	end

	############
	### priv ###
	############

	defp refresh_state(state = %Pool{stamp: stamp}) do
		case (Exutils.makestamp - stamp) > @timeout do
			true -> create_chans_if_need(state)
						|> HashUtils.modify_all([:channels], &(refresh_chan(&1, state)) )
							|> HashUtils.set(:stamp, Exutils.makestamp)
			false -> state
		end
	end
	defp create_chans_if_need(state = %Pool{size: size, channels: channels}) do
		case (HashUtils.keys(channels) |> length) == size do
			true -> state
			false -> Enum.reduce(1..size, state,
						fn(num, state) ->
							case HashUtils.get(channels, num) do
								nil -> HashUtils.add(state, [:channels, num], create_chan(num, state) )
								_ 	-> state
							end
						end )
		end
	end
	defp create_chan(num, pool = %Pool{	poolname: poolname }) do
		case get_conn(pool) do
			{:error, error} -> %Rabbitex.Chan{pool: poolname,
								              conn: nil,
								              chan: nil,
								              number: num,
								              status: {:error, error}}
			conn -> case get_chan(conn) do
						{:error, error} -> %Rabbitex.Chan{pool: poolname,
											              conn: nil,
											              chan: nil,
											              number: num,
											              status: {:error, error}}
						chan ->  		%Rabbitex.Chan{	pool: poolname,
														conn: conn,
														chan: chan,
														number: num,
														status: :ok }
					end
		end
	end


	defp refresh_chan(%Rabbitex.Chan{number: num, status: {:error, _}, busy: false}, state ) do
		create_chan(num, state)
	end
	defp refresh_chan(fullchan = %Rabbitex.Chan{number: num, conn: conn, chan: chan, status: :ok, busy: false}, state ) do
		case :erlang.process_info(chan) != :undefined do
			true -> fullchan
			false -> case :erlang.process_info(conn) != :undefined do
						true -> case get_chan(conn) do
									{:error, _} -> create_chan(num, state)
									new_chan -> HashUtils.set(fullchan, :chan, new_chan)
								end
						false -> create_chan(num, state)
					end
		end
	end
	# if chan is busy, do nothing
	defp refresh_chan(fullchan, _) do
		fullchan
	end


	defp get_conn(%Pool{username: username,
						password: password,
						host: host,
						virtual_host: virtual_host,
						heartbeat: heartbeat }) do
		case Retry.run(%{sleep: 50, tries: 3}, 
				fn() ->	Exrabbit.Utils.connect([	username: username, 
													password: password, 
													host: host,
													virtual_host: virtual_host,
													heartbeat: heartbeat ]) end ) do
			{:ok, conn} when is_pid(conn) -> conn
			error -> {:error, error}
		end
	end
	defp get_chan(conn) do
		case Retry.run(%{sleep: 50, tries: 3}, fn() -> Exrabbit.Utils.channel_open(conn) end ) do
			{:ok, chan} when is_pid(chan) -> chan
			error -> {:error, error}
		end
	end


end