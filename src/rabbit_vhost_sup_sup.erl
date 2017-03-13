%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2007-2016 Pivotal Software, Inc.  All rights reserved.
%%

-module(rabbit_vhost_sup_sup).

-include("rabbit.hrl").

-behaviour(supervisor2).

-export([init/1]).

-export([start_link/0, start/0, ensure_started/0]).
-export([vhost_sup/1]).
-export([start_vhost/1]).

start() ->
    rabbit_sup:start_supervisor_child(?MODULE).

ensure_started() ->
    case start() of
        ok                            -> ok;
        {error, {already_started, _}} -> ok;
        Other                         -> Other
    end.

start_link() ->
    supervisor2:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    ets:new(?MODULE, [named_table, public]),
    {ok, {{simple_one_for_one, 1, 5},
          [{rabbit_vhost, {rabbit_vhost_sup_sup, start_vhost, []},
            transient, infinity, supervisor,
            [rabbit_vhost_sup_sup, rabbit_vhost_sup]}]}}.

start_vhost(VHost) ->
    case vhost_pid(VHost) of
        no_pid ->
            case rabbit_vhost_sup:start_link(VHost) of
                {ok, Pid} ->
                    ok = save_vhost_pid(VHost, Pid),
                    {ok, Pid};
                Other     -> Other
            end;
        Pid when is_pid(Pid) ->
            {error, {already_started, Pid}}
    end.

-spec vhost_sup(rabbit_types:vhost()) -> {ok, pid()}.
vhost_sup(VHost) ->
    case supervisor2:start_child(?MODULE, [VHost]) of
        {ok, Pid}                       -> {ok, Pid};
        {error, {already_started, Pid}} -> {ok, Pid};
        Error                           -> throw(Error)
    end.

save_vhost_pid(VHost, Pid) ->
    true = ets:insert(?MODULE, {VHost, Pid}),
    ok.

-spec vhost_pid(rabbit_types:vhost()) -> no_pid | pid().
vhost_pid(VHost) ->
    case ets:lookup(?MODULE, VHost) of
        []    -> no_pid;
        [{VHost, Pid}] ->
            case erlang:is_process_alive(Pid) of
                true  -> Pid;
                false ->
                    ets:delete_object(?MODULE, {VHost, Pid}),
                    no_pid
            end
    end.
