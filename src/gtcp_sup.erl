%%%-------------------------------------------------------------------
%% @doc gtcp top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(gtcp_sup).

-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%% sup_flags() = #{strategy => strategy(),         % optional
%%                 intensity => non_neg_integer(), % optional
%%                 period => pos_integer()}        % optional
%% child_spec() = #{id => child_id(),       % mandatory
%%                  start => mfargs(),      % mandatory
%%                  restart => restart(),   % optional
%%                  shutdown => shutdown(), % optional
%%                  type => worker(),       % optional
%%                  modules => modules()}   % optional
init([]) ->
    SupFlags = #{strategy => one_for_all,
                 intensity => 0,
                 period => 1},
    ChildSpecs = [tcp_acpt_spec(), tcp_srv_sup_spec()],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions
tcp_acpt_spec() ->
    #{id => gtcp_acpt,
      start => {gtcp_acpt,start_link,[]},
      restart => permanent,
      shutdown => 2000,
      type => worker,
      modules => [gtcp_acpt]}.

tcp_srv_sup_spec() ->
    #{id => gtcp_srv_sup,
      start => {gtcp_srv_sup,start_link,[]},
      restart => permanent,
      shutdown => 2000,
      type => supervisor,
      modules => [gtcp_srv_sup]}.

