%%%------------------------------------------------------------------------
%%% @author Artur Stefanowicz (artur.stefanowicz7@gmail.com)
%%% @copyright (C) 2020, Artur Stefanowicz
%%% @doc
%%% Full-duplex TCP Serwer z nowym mechanizmem obslugi (socket) : SENDER
%%% @end
%%% Created : 28 Nov 2020 by artur.stefanowicz7@gmail.com
%%%------------------------------------------------------------------------
-module(gtcp_vctr_sender).

-behaviour(gen_server).

%% API
-export([start_link/3]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3, format_status/2]).


-define(PFX_LEN,2).
-define(SEND_TIMEOUT,5).
-define(SERVER, ?MODULE).

-record(state, {vctr,sck}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%% @end
%%--------------------------------------------------------------------
-spec start_link(VCTR :: pid(), SCK :: term(), N :: integer()) -> {ok, Pid :: pid()} |
	  {error, Error :: {already_started, pid()}} |
	  {error, Error :: term()} |
	  ignore.
start_link(VCTR,SCK,N) ->
    gen_server:start_link({local,gtcp_acpt:generate_unique_name(?MODULE,N)}, ?MODULE, [VCTR,SCK], []).

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
init([VCTR,SCK]) ->
    process_flag(trap_exit, true),
    {ok, #state{vctr=VCTR,sck=SCK}}.

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
    {noreply,State};

%% handle_info(timeout,State)->
%%     logger:info("handle_info: timeout->starting new message.",[]),
%%     case process_event(State) of
%% 	{datareq,State1} ->
%% 	    {noreply,State1,0};
%% 	{pending,State1} ->
%% 	    {noreply,State1};
%% 	{error,ER} ->
%% 	    logger:error("handle_info: error=~p. Stopping as normal",[ER]),
%% 	    {stop,normal,State}
%%     end;

%% handle_info({'$socket',_SCK,select,_REF}, State) ->
%%     logger:info("handle_info: select ...",[]),
%%     case process_event(State) of
%% 	{datareq,State1} ->
%% 	    {noreply,State1,0};
%% 	{pending,State1} ->
%% 	    {noreply,State1};
%% 	{error,ER} ->
%% 	    logger:error("handle_info: error=~p. Stopping as normal",[ER]),
%% 	    {stop,normal,State}
%%     end;

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

handle_info({'EXIT',VCTR,Reason}, #state{vctr=VCTR}=State) ->
    logger:info("handle_info: Exiting, reason=~p",[Reason]),
    {stop,Reason,State};

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
-spec send_message(SCK :: term(), Data :: binary()) -> term().
send_message(SCK,Data) ->
    LEN = length(binary:bin_to_list(Data)),
    socket:send(SCK,<<LEN:(?PFX_LEN*8)/integer-unsigned,Data/binary>>,?SEND_TIMEOUT).
