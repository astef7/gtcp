%%%-------------------------------------------------------------------
%% @doc gtcp public API
%% @end
%%%-------------------------------------------------------------------

-module(gtcp_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    logger:set_primary_config(level,info),
    logger:set_handler_config(default,
			      formatter,
			      {logger_formatter, 
			       #{
				 legacy_header => false,
				 single_line => true,
				 template => [time," ",level,"[",pid,"]",file," ",msg,"\n"]}}),
    gtcp_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
