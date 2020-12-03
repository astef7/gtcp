%%%-------------------------------------------------------------------
%%% @author Artur Stefanowicz (artur.stefanowicz7@gmail.com)
%%% @copyright (C) 2020, Artur Stefanowicz
%%% @doc
%%% Dynamic gtcp_srv Supervisor
%%% @end
%%% Created : 28 Nov 2020 by artur.stefanowicz7@gmail.com
%%%-------------------------------------------------------------------
-module(gtcp_srv_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API functions
%%%===================================================================
-export([add_async_srv/2]).
-export([add_fduplex_srv/2,add_fduplex_sender/3,add_fduplex_receiver/4]).

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%% @end
%%--------------------------------------------------------------------
-spec start_link() -> {ok, Pid :: pid()} |
	  {error, {already_started, Pid :: pid()}} |
	  {error, {shutdown, term()}} |
	  {error, term()} |
	  ignore.
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart intensity, and child
%% specifications.
%% @end
%%--------------------------------------------------------------------
-spec init(Args :: term()) ->
	  {ok, {SupFlags :: supervisor:sup_flags(),
		[ChildSpec :: supervisor:child_spec()]}} |
	  ignore.
init([]) ->
    logger:info("gtcp_srv_sup:init called...",[]),
    SupFlags = #{strategy => one_for_one,
		 intensity => 1,
		 period => 5},

    {ok, {SupFlags, []}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
-spec add_async_srv(SCK :: term(), N :: integer()) -> 
	  {ok,supervisor:child()} |
	  {ok,supervisor:child(),term()} |
	  {error,term()}.
add_async_srv(SCK,N)->
    AChild = #{id => gtcp:generate_unique_name(gtcp_async_srv,N),
	       start => {gtcp_async_srv, start_link, [SCK,N]},
	       restart => temporary,
	       shutdown => 5000,
	       type => worker,
	       modules => [gtcp_async_srv]},
    logger:info("adding child [async_srv] CHD=~p~n",[AChild]),
    supervisor:start_child(?MODULE,AChild).

-spec add_fduplex_srv(SCK :: term(), N :: integer()) ->
	  {ok,supervisor:child()} |
	  {ok,supervisor:child(),term()} |
	  {error,term()}.
add_fduplex_srv(SCK,N)->
    AChild = #{id => gtcp:generate_unique_name(vctr,N),
	       start => {gtcp_vctr_srv, start_link, [SCK,N]},
	       restart => temporary,
	       shutdown => 5000,
	       type => worker,
	       modules => [gtcp_vctr_srv]},
    logger:info("adding child [fduplex_srv] CHD=~p~n",[AChild]),
    supervisor:start_child(?MODULE,AChild).

-spec add_fduplex_sender(VCTR :: pid(), SCK :: term(), N :: integer()) ->
	  {ok,supervisor:child()} |
	  {ok,supervisor:child(),term()} |
	  {error,term()}.
add_fduplex_sender(VCTR,SCK,N)->
    AChild = #{id => gtcp:generate_unique_name(sender,N,"_snd"),
	       start => {gtcp_vctr_sender, start_link, [VCTR,SCK,N]},
	       restart => temporary,
	       shutdown => 5000,
	       type => worker,
	       modules => [gtcp_vctr_sender]},
    logger:info("adding child [fduplex_sender] CHD=~p~n",[AChild]),
    supervisor:start_child(?MODULE,AChild).

-spec add_fduplex_receiver(VCTR :: pid(), SENDER :: pid(), SCK :: term(), N :: integer()) ->
	  {ok,supervisor:child()} |
	  {ok,supervisor:child(),term()} |
	  {error,term()}.
add_fduplex_receiver(VCTR,SENDER,SCK,N)->
    AChild = #{id => gtcp:generate_unique_name(receiver,N,"_rcv"),
	       start => {gtcp_vctr_receiver, start_link, [VCTR,SENDER,SCK,N]},
	       restart => temporary,
	       shutdown => 5000,
	       type => worker,
	       modules => [gtcp_vctr_receiver]},
    logger:info("adding child [fduplex_receiver] CHD=~p~n",[AChild]),
    supervisor:start_child(?MODULE,AChild).
