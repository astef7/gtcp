%%%--------------------------------------------------------------------------------
%%% @author Artur Stefanowicz (artur.stefanowicz7@gmail.com)
%%% @copyright (C) 2020, Artur Stefanowicz
%%% @doc
%%% Full-duplex TCP Serwer z nowym mechanizmem obslugi (socket) : V-Controler
%%% @end
%%% Created : 28 Nov 2020 by artur.stefanowicz7@gmail.com
%%%--------------------------------------------------------------------------------
-module(gtcp_vctr_srv).

-behaviour(gen_server).

%% API
-export([start_link/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3, format_status/2]).

%% -define(PFX_LEN,2).
%% -define(BLOCK_SIZE,64000).
%% -define(SEND_TIMEOUT,5).
-define(SERVER, ?MODULE).

-record(state, {snd,rcv,sck,n}).


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
    gen_server:start_link({local,gtcp:generate_unique_name(?MODULE,N)}, ?MODULE, [SCK,N], []).

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
init([SCK,N]) ->
    process_flag(trap_exit, true),
    {ok, #state{sck=SCK,n=N}}.

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

handle_info({initialization_done}, #state{sck=SCK,n=N}=State) ->
    logger:info("handle_info: INITIALIZATION DONE.",[]),

    {ok,SENDER} = gtcp_srv_sup:add_fduplex_sender(self(),SCK,N),
    {ok,RECEIVER} = gtcp_srv_sup:add_fduplex_receiver(self(),SENDER,SCK,N),

    _SndRef = erlang:monitor(process,SENDER),
    _RcvRef = erlang:monitor(process,RECEIVER),

    SENDER ! {initialization_done},	    
    RECEIVER ! {initialization_done},

    {noreply,State#state{snd=SENDER,rcv=RECEIVER}};

%% Sender DOWN ...
handle_info({'DOWN',_Ref,process,PID,Reason}, #state{snd=PID,rcv=RCV}=State) ->
    logger:error("handle_info: Sender DOWN, reason=~p~n",[Reason]),
    exit(RCV,Reason),
    {stop,normal,State};

%% Receiver DOWN ...
handle_info({'DOWN',_Ref,process,PID,Reason}, #state{snd=SND,rcv=PID}=State) ->
    logger:error("handle_info: Receiver DOWN, reason=~p~n",[Reason]),
    exit(SND,Reason),
    {stop,normal,State};

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
%% -spec generate_unique_name(TYPE :: atom(), N :: integer()) -> atom().
%% generate_unique_name(vctr,N) ->
%%     list_to_atom("gtcp_vctr_"++integer_to_list(N));
%% generate_unique_name(sender,N) ->
%%     list_to_atom("gtcp_vctr_"++integer_to_list(N)++"_snd");
%% generate_unique_name(receiver,N) ->
%%     list_to_atom("gtcp_vctr_"++integer_to_list(N)++"_rcv").    
