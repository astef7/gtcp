%%%-------------------------------------------------------------------
%%% @author Artur Stefanowicz (artur.stefanowicz7@gmail.com)
%%% @copyright (C) 2020, Artur Stefanowicz
%%% @doc
%%% Asynchronous TCP Server acceptor, using new Erlang "socket" module
%%% @end
%%% Created : 28 Nov 2020 by artur.stefanowicz7@gmail.com
%%%-------------------------------------------------------------------
-module(gtcp_acpt).

-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3, format_status/2]).

-define(SERVER, ?MODULE).
%%-define(PORT, 8091).
%%-define(DEFAULT_LENGTH_PFX,2).
-define(SERVER_CREATION_FUN,add_fduplex_srv). %% [add_async_srv | add_fduplex_srv]

-record(state, {lsck,select,n=0}).

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%% @end
%%--------------------------------------------------------------------
-spec start_link() -> {ok, Pid :: pid()} |
	  {error, Error :: {already_started, pid()}} |
	  {error, Error :: term()} |
	  ignore.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

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
init([]) ->
    process_flag(trap_exit, true),
    {ok,LS} = socket:open(inet,stream,tcp),
    ok = socket:setopt(LS,socket,reuseaddr,true),
    {ok,_PORT} = socket:bind(LS,#{family => inet, port => gtcp:get_port(), addr => {127,0,0,1}}),

    ok = socket:listen(LS),

    {select,SI,N} = accept(LS,0),    

    {ok,#state{lsck=LS,select=SI,n=N}}.

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

handle_info({'$socket',LS,select,REF}, #state{lsck=LS,select=SEL,n=N}=State) ->
    logger:info("handle_info: ACCEPT EVENT, LS=~p, REF=~p",[LS,REF]),

    %% Pro-forma matching dla sprawdzenia zgodnosci REF:
    {select_info,accept,REF}=SEL,

    {select,SI,N1} = accept(LS,N),    

    {noreply, State#state{select=SI,n=N1}};

handle_info({'DOWN',_Ref,process,PID,Reason}, State) ->
    logger:info("handle_info: process DOWN, pid=~p, reason=~p",[PID,Reason]),
    {noreply, State};

handle_info(Unknown, State) ->
    logger:error("handle_info: UNKNOWN=~p",[Unknown]),
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
-spec accept(LS :: socket:socket(), N :: integer()) -> 
	  {select, SI :: term(), N :: integer()} | 
	  {error,ER :: term()}.
accept(LS,N) ->
    case socket:accept(LS,nowait) of
	{ok,SCK} -> 
	    logger:info("accept: accept completed passing N=~p, Server mode=~p.",[N,?SERVER_CREATION_FUN]),
	    {ok,PID}=apply(gtcp_srv_sup,?SERVER_CREATION_FUN,[SCK,N]),
	    logger:info("accept: worker created, PID=~p.",[PID]),
	    erlang:monitor(process,PID),
	    
	    PID ! {initialization_done},
	    
	    accept(LS,N+1);
	
	{select,SI} -> logger:info("accept: SI=~p",[SI]),
		       {select,SI,N};

	{error,ER} -> logger:error("accept: error ER=~p",[ER]),
		      error(ER)
    end.
