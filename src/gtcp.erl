%%%-------------------------------------------------------------------
%%% @author Artur Stefanowicz (artur.stefanowicz7@gmail.com)
%%% @copyright (C) 2020, Artur Stefanowicz
%%% @doc
%%% Asynchroniczny serwer TCP z nowym mechanizmem obslugi (socket) i 
%%% blokowym przetwarzaniem bufora : funkcje biblioteczne
%%% @end
%%% Created : 03 Dec 2020 by artur.stefanowicz7@gmail.com
%%%-------------------------------------------------------------------
-module(gtcp).

%% API
-export([connect/0,
	 connect/1,
	 close/1,
	 send/2]).
-export([which_children/0,
	 which_children/1]).

%% Internal functions
-export([process_event/2,
	 send_message/2,
	 get_port/0,
	 generate_unique_name/2,
	 generate_unique_name/3,
	 worker/2]).

-define(PORT, 8091).
-define(PFX_LEN,2).
-define(BLOCK_SIZE,64000).
-define(MAX_PACKET_SIZE,32000).
-define(SEND_TIMEOUT,5).
-define(SYSTEM_PACKET_DECODER,true).

-record(io, {buff,select,responser}).

%% Implementation...
-spec connect() -> {ok, Socket :: port()}.
connect()->
    gen_tcp:connect({127,0,0,1},?PORT,[{active,true},{packet,?PFX_LEN},binary]).

-spec connect(raw) -> {ok, Socket :: port()}.
connect(raw)->
    gen_tcp:connect({127,0,0,1},?PORT,[{active,true},binary]).

-spec close(Socket :: port()) -> ok.
close(SCK)->
    gen_tcp:close(SCK).

-spec send(Socket :: port(), Data :: binary()) -> ok | {error, Reason :: term()}.
send(SCK,Data)->
    gen_tcp:send(SCK,Data).

-spec which_children() -> [term()].
which_children()->
    supervisor:which_children(gtcp_srv_sup).

-spec which_children(top) -> [term()].
which_children(top)->
    supervisor:which_children(gtcp_sup).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Process name
%% @end
%%--------------------------------------------------------------------
-spec generate_unique_name(Name :: atom(),N :: integer()) -> atom().
generate_unique_name(Name,N) ->
    list_to_atom(atom_to_list(Name)++"_"++integer_to_list(N)).    

-spec generate_unique_name(Name :: atom(),N :: integer(),Sfx :: string()) -> atom().
generate_unique_name(Name,N,Sfx) ->
    list_to_atom(atom_to_list(Name)++"_"++integer_to_list(N)++Sfx).    

-spec get_port() -> integer().
get_port() ->
    ?PORT.

-spec process_event(SCK :: term(), IO :: term()) ->
	  {datareq,IORet :: term()} | 
	  {pending,IORet :: term()} | 
	  {error,ER :: term()}.
process_event(SCK,IO) when is_record(IO,io) ->
    logger:info("process_event...",[]),
    case recv_bytes(SCK,IO) of
	{ok,#io{buff=BUFF}=IO2} ->
	    logger:info("Completed MSG/immediate, BUFF=~p, IO=~p",[BUFF,IO2]),
	    {datareq,_IORet} = process_buffer(IO2);

	{pending,IO2} ->
	    logger:info("Pending IO=~p",[IO2]),
	    {pending,IO2};

	{error,ER} ->
	    logger:error("Error=~p",[ER]),
	    {error,ER}
    end.

-spec process_buffer(IO :: term()) ->
	  {datareq,IO :: term()}.
process_buffer(#io{buff=BUFF,responser=RESPONSER}=IO) when is_binary(BUFF) ->
    if
	?SYSTEM_PACKET_DECODER =:= true ->
	    logger:info("process_buffer[sys], IO=~p",[IO]),
	    case erlang:decode_packet(?PFX_LEN,BUFF,[{packet_size,?MAX_PACKET_SIZE}]) of
		{ok,Packet,Rest}->
		    spawn(gtcp,worker,[RESPONSER,Packet]),
		    process_buffer(IO#io{buff=Rest});
		{more,Length}->
		    {datareq,IO};
		{error,ER}->
		    logger:error("process_buffer[sys], ER=~p",[ER]),
		    error(ER)
		end;
	true ->
	    logger:info("process_buffer[own], IO=~p",[IO]),
	    case erlang:byte_size(BUFF) - ?PFX_LEN > 0 of
		true ->
		    <<PFX:?PFX_LEN/binary,REST1/binary>> = BUFF,
		    LEN = binary:decode_unsigned(PFX),
		    logger:info("process_buffer[own], PFX=~p, LEN=~p,len_rest=~p~n",
			      [PFX,LEN,erlang:byte_size(REST1)]),
		    case (erlang:byte_size(REST1) - LEN) >= 0 of
			true ->
			    <<MSG:LEN/binary,REST2/binary>> = REST1,
			    spawn(gtcp,worker,[RESPONSER,MSG]),
			    process_buffer(IO#io{buff=REST2});
			false ->
			    {datareq,IO}
		    end;
		false ->
		    {datareq,IO}
	    end
    end.

-spec recv_bytes(SCK :: term(), IO :: term()) ->
	  {ok,IO :: term()} | {pending,IO :: term()} | {error,ER :: term()}.
recv_bytes(SCK,#io{buff=BUFF}=IO) ->
    case socket:recv(SCK,?BLOCK_SIZE,nowait) of
	{ok,{Chunk,SI2}} -> 
	    logger:info("got PARTIAL data and SI, data=~p",[Chunk]),
	    {ok,IO#io{select=SI2,buff= <<BUFF/binary,Chunk/binary>>}};
	{ok,Chunk} -> 
	    logger:info("got data,full,data=~p",[Chunk]),
	    {ok,IO#io{select=none,buff=Chunk}};
	{select,SI2} -> 
	    logger:info("got SI=~p",[SI2]),
	    {pending,IO#io{select=SI2}};
	{error,ER} -> 
	    logger:info("got ER=~p",[ER]),
	    {error,ER}
    end.

-spec send_message(SCK :: term(), Data :: binary()) -> term().
send_message(SCK,Data) ->
    LEN = length(binary:bin_to_list(Data)),
    socket:send(SCK,<<LEN:(?PFX_LEN*8)/integer-unsigned,Data/binary>>,?SEND_TIMEOUT).

-spec worker(SRV :: pid(), MSG :: binary()) -> no_return().
worker(SRV, MSG)->
    logger:info("worker called for MSG=~p",[MSG]),
    SRV ! {send_data,<<"RESPONSE:",MSG/binary>>}.
