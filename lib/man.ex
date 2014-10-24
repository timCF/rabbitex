defmodule Rabbitex.Man do
	use ExActor.GenServer

	defmodule Pool do
		@derive [HashUtils]
		defstruct 	username: "",
					password: "",
					host: '',
					virtual_host: "",
					heartbeat: 1,
					size: 1,
					channels: %{}
	end

	@timeout :timer.minutes(1)

	definit %{nameproc: nameproc, size: size} do
		:erlang.register(nameproc, self)
		{:ok, %Pool{size: size}, 0}
	end

	definfo :timeout, state: state do
		{
			:noreply,
			create_chans_if_need(state)
				|> HashUtils.modify_all([:channels], &refresh_chan),
			@timeout
		}
	end

	defp create_chans_if_need(state = %Pool{size: size, channels: chans}) do
		Enum.reduce(1..size, state,
			fn(num) ->
				case HashUtils.get(chans, num) do
					nil -> HashUtils.add(state, [:channels, num], create_chan(num) )

				end
			end )
	end

end