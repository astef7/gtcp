%%%-------------------------------------------------------------------
%%% @author Artur Stefanowicz (artur.stefanowicz7@gmail.com)
%%% @copyright (C) 2020, Artur Stefanowicz
%%% @doc
%%% Asynchroniczny serwer TCP z nowym mechanizmem obslugi (socket) i 
%%% blokowym przetwarzaniem bufora
%%% @end
%%% Created : 28 Nov 2020 by artur.stefanowicz7@gmail.com
%%%-------------------------------------------------------------------
-module(gtcp_async_srv).

-behaviour(gen_server).

%% API
-export([start_link/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3, format_status/2]).

-export([worker/2]).

-define(PFX_LEN,2).
-define(BLOCK_SIZE,64000).
-define(SEND_TIMEOUT,5).
-define(SERVER, ?MODULE).

-record(io, {buff,select}).
-record(state, {sck,io = #io{}}).


%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%% @end
%%--------------------------------------------------------------------
-spec start_link(SCK :: term(), N :: integer()) -> {ok, Pid :: pid()} |
	  {error, Error :: {already_started, pid()}} |
	  {error, Error :: term()} |
	  ignore.
start_link(SCK,N) ->
    gen_server:start_link({local,gtcp_acpt:generate_unique_name(?MODULE,N)}, ?MODULE, [SCK], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%% @end
%%--------------------------------------------------------------------
-spec init(Args :: term()) -> {ok, State :: term()} |
	  {ok, State :: term(), Timeout :: timeout()} |
	  {ok, State :: term(), hibernate} |
	  {stop, Reason :: term()} |
	  ignore.
init([SCK]) ->
    process_flag(trap_exit, true),
    {ok, #state{sck=SCK}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%% @end
%%--------------------------------------------------------------------
-spec handle_call(Request :: term(), From :: {pid(), term()}, State :: term()) ->
	  {reply, Reply :: term(), NewState :: term()} |
	  {reply, Reply :: term(), NewState :: term(), Timeout :: timeout()} |
	  {reply, Reply :: term(), NewState :: term(), hibernate} |
	  {noreply, NewState :: term()} |
	  {noreply, NewState :: term(), Timeout :: timeout()} |
	  {noreply, NewState :: term(), hibernate} |
	  {stop, Reason :: term(), Reply :: term(), NewState :: term()} |
	  {stop, Reason :: term(), NewState :: term()}.
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%% @end
%%--------------------------------------------------------------------
-spec handle_cast(Request :: term(), State :: term()) ->
	  {noreply, NewState :: term()} |
	  {noreply, NewState :: term(), Timeout :: timeout()} |
	  {noreply, NewState :: term(), hibernate} |
	  {stop, Reason :: term(), NewState :: term()}.
handle_cast(_Request, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%% @end
%%--------------------------------------------------------------------
-spec handle_info(Info :: timeout() | term(), State :: term()) ->
	  {noreply, NewState :: term()} |
	  {noreply, NewState :: term(), Timeout :: timeout()} |
	  {noreply, NewState :: term(), hibernate} |
	  {stop, Reason :: normal | term(), NewState :: term()}.

handle_info({initialization_done}, #state{sck=SCK}=State) ->
    logger:info("handle_info: INITIALIZATION DONE.",[]),

    ok = socket:setopt(SCK,tcp,nodelay,true),

%%    ok = socket:setopt(SCK,tcp,keepalive,true),
%%    ok = socket:setopt(SCK,tcp,linger,true),
    {noreply,State#state{io = #io{buff= <<>>}},0};

handle_info(timeout,State)->
    logger:info("handle_info: timeout->starting new message.",[]),
    case process_event(State) of
	{datareq,State1} ->
	    {noreply,State1,0};
	{pending,State1} ->
	    {noreply,State1};
	{error,ER} ->
	    logger:error("handle_info: error=~p. Stopping as normal",[ER]),
	    {stop,normal,State}
    end;

handle_info({'$socket',_SCK,select,_REF}, State) ->
    logger:info("handle_info: select ...",[]),
    case process_event(State) of
	{datareq,State1} ->
	    {noreply,State1,0};
	{pending,State1} ->
	    {noreply,State1};
	{error,ER} ->
	    logger:error("handle_info: error=~p. Stopping as normal",[ER]),
	    {stop,normal,State}
    end;

handle_info({send_data,RESP}, #state{sck=SCK}=State) ->
    logger:info("handle_info: send_data REQ, data (response)=~p",[RESP]),
    case send_message(SCK,RESP) of
	ok ->
	    ok;
	{error,ER} ->
	    logger:info("handle_info: socket:send error=~p",[ER]),
	    error(ER)
    end,
    {noreply,State};

%% --> nie wykorzystywane w przypadku modulu <socket>
%% handle_info({tcp,FROM,MSG}, #state{sck=SCK}=State) ->
%%     logger:info("handle_info: tcp msg=~p~n",[MSG]),
%%     gen_tcp:send(FROM,<<"REPLY:",MSG/binary>>),
%%     ok = inet:setopts(SCK,[{active,once}]),
%%     {noreply, State};

%% --> nie wykorzystywane w przypadku modulu <socket>
%% handle_info({tcp_closed,SCK}, #state{sck=SCK}=State) ->
%%     logger:info("handle_info: tcp_closed~n",[]),
%%     gen_tcp:close(SCK),
%%     {stop, tcp_closed, State};

%% --> nie wykorzystywane w przypadku modulu <socket>
%% handle_info({tcp_error,SCK,Reason}, #state{sck=SCK}=State) ->
%%     logger:info("handle_info: tcp_error, ER=~p~n",[Reason]),
%%     gen_tcp:close(SCK),
%%     {stop, tcp_error, State};

%% --> nie wykorzystywane w przypadku modulu <socket>
%% handle_info({error,timeout}, #state{sck=SCK}=State) ->
%%     logger:info("handle_info: send timeout error~n",[]),
%%     gen_tcp:close(SCK),
%%     {stop, send_timeout, State};

handle_info(Unknown, State) ->
    logger:error("handle_info: UNKNOWN=~p~n",[Unknown]),
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%% @end
%%--------------------------------------------------------------------
-spec terminate(Reason :: normal | shutdown | {shutdown, term()} | term(),
		State :: term()) -> any().
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%% @end
%%--------------------------------------------------------------------
-spec code_change(OldVsn :: term() | {down, term()},
		  State :: term(),
		  Extra :: term()) -> {ok, NewState :: term()} |
	  {error, Reason :: term()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called for changing the form and appearance
%% of gen_server status when it is returned from sys:get_status/1,2
%% or when it appears in termination error logs.
%% @end
%%--------------------------------------------------------------------
-spec format_status(Opt :: normal | terminate,
		    Status :: list()) -> Status :: term().
format_status(_Opt, Status) ->
    Status.

%%%===================================================================
%%% Internal functions
%%%===================================================================
-spec process_event(State :: term()) ->
	  {datareq,State :: term()} | 
	  {pending,State :: term()} | 
	  {error,ER :: term()}.
process_event(#state{sck=SCK,io=IO}=State) ->
    logger:info("process_event...",[]),
    case recv_bytes(SCK,IO) of
	{ok,#io{buff=BUFF}=IO2} ->
	    logger:info("Completed MSG/immediate, BUFF=~p, IO=~p",[BUFF,IO2]),
	    {datareq,IO3} = process_buffer(IO2),
	    {datareq, State#state{io=IO3}};

	{pending,IO2} ->
	    logger:info("Pending IO=~p",[IO2]),
	    {pending, State#state{io=IO2}};

	{error,ER} ->
	    logger:error("Error=~p",[ER]),
	    {error,ER}
    end.

-spec process_buffer(IO :: term()) ->
	  {datareq,IO :: term()}.
process_buffer(#io{buff=BUFF}=IO) when is_binary(BUFF) ->
    io:format("process_buffer, IO=~p",[IO]),
    case erlang:byte_size(BUFF) - ?PFX_LEN > 0 of
	true ->
	    <<PFX:?PFX_LEN/binary,REST1/binary>> = BUFF,
	    LEN = binary:decode_unsigned(PFX),
	    io:format("process_buffer, PFX=~p, LEN=~p,len_rest=~p~n",[PFX,LEN,erlang:byte_size(REST1)]),
	    case (erlang:byte_size(REST1) - LEN) >= 0 of
		true ->
		    <<MSG:LEN/binary,REST2/binary>> = REST1,
		    spawn(?MODULE,worker,[self(),MSG]),
		    process_buffer(IO#io{buff=REST2});
		false ->
		    {datareq,IO}
		end;
	false ->
	    {datareq,IO}
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
