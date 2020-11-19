%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%
%% Copyright (c) 2007-2020 VMware, Inc. or its affiliates.  All rights reserved.
%%

-module(rabbit_stream_connections_mgmt).

-behaviour(rabbit_mgmt_extension).

-export([dispatcher/0, web_ui/0]).
-export([init/2, to_json/2, content_types_provided/2, is_authorized/2]).

-include_lib("rabbitmq_management_agent/include/rabbit_mgmt_records.hrl").

dispatcher() -> [{"/stream-connections",        ?MODULE, []}].

web_ui()     -> [{javascript, <<"stream.js">>}].

%%--------------------------------------------------------------------

init(Req, _Opts) ->
  {cowboy_rest, rabbit_mgmt_cors:set_headers(Req, ?MODULE), #context{}}.

content_types_provided(ReqData, Context) ->
  {[{<<"application/json">>, to_json}], ReqData, Context}.

to_json(ReqData, Context) ->
  try
    Connections = keep_stream_connections(do_connections_query(ReqData, Context)),
    rabbit_mgmt_util:reply_list_or_paginate(Connections, ReqData, Context)
  catch
    {error, invalid_range_parameters, Reason} ->
      rabbit_mgmt_util:bad_request(iolist_to_binary(Reason), ReqData, Context)
  end.

is_authorized(ReqData, Context) ->
  rabbit_mgmt_util:is_authorized(ReqData, Context).

augmented(ReqData, Context) ->
  rabbit_mgmt_util:filter_conn_ch_list(
    rabbit_mgmt_db:get_all_connections(
      rabbit_mgmt_util:range_ceil(ReqData)), ReqData, Context).

do_connections_query(ReqData, Context) ->
  case rabbit_mgmt_util:disable_stats(ReqData) of
    false ->
      augmented(ReqData, Context);
    true ->
      rabbit_mgmt_util:filter_tracked_conn_list(rabbit_connection_tracking:list(),
        ReqData, Context)
  end.

keep_stream_connections(Connections) ->
  lists:filter(fun(Connection) ->
    case lists:keyfind(protocol, 1, Connection) of
      {protocol, <<"stream">>} ->
        true;
      _ ->
        false
    end
               end, Connections).