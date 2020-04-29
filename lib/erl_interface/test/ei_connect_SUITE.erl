%%
%% %CopyrightBegin%
%% 
%% Copyright Ericsson AB 2001-2020. All Rights Reserved.
%% 
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%% 
%% %CopyrightEnd%
%%

%%
-module(ei_connect_SUITE).

-include_lib("common_test/include/ct.hrl").
-include("ei_connect_SUITE_data/ei_connect_test_cases.hrl").

-export([all/0, suite/0, groups/0,
         init_per_testcase/2,
         ei_send/1,
         ei_reg_send/1,
         ei_format_pid/1,
         ei_rpc/1,
         rpc_test/1,
         ei_send_funs/1,
         ei_threaded_send/1,
         ei_set_get_tracelevel/1,
         ei_connect_host_port_test/1,
         ei_make_ref/1]).

-import(runner, [get_term/1,send_term/2]).

suite() ->
    [{ct_hooks,[ts_install_cth]},
     {timetrap, {seconds, 240}}].

all() -> 
    [ei_threaded_send,
     ei_connect_host_port_test,
     {group, default},
     {group, ussi},
     ei_make_ref].

groups() ->
    Members = [ei_send,
               ei_format_pid,
               ei_send_funs,
               ei_set_get_tracelevel,
               ei_reg_send,
               ei_rpc],
    [{default, [], Members},
     {ussi, [], Members}].

get_group(Config) ->
    proplists:get_value(name, proplists:get_value(tc_group_properties,Config)).

init_per_testcase(Case, Config) ->
    runner:init_per_testcase(?MODULE, Case, Config).

ei_send(Config) when is_list(Config) ->
    P = runner:start(Config, ?interpret),
    0 = ei_connect_init(P, 42, erlang:get_cookie(), 0, get_group(Config)),
    {ok,Fd} = ei_connect(P, node()),

    ok = ei_send(P, Fd, self(), AMsg={a,message}),
    receive AMsg -> ok end,

    runner:send_eot(P),
    runner:recv_eot(P),
    ok.

ei_format_pid(Config) when is_list(Config) ->
    S = self(),
    P = runner:start(Config, ?interpret),
    0 = ei_connect_init(P, 42, erlang:get_cookie(), 0, get_group(Config)),
    {ok,Fd} = ei_connect(P, node()),

    ok = ei_format_pid(P, Fd, S),
    receive S -> ok end,

    runner:send_eot(P),
    runner:recv_eot(P),
    ok.

ei_send_funs(Config) when is_list(Config) ->
    P = runner:start(Config, ?interpret),
    0 = ei_connect_init(P, 42, erlang:get_cookie(), 0, get_group(Config)),
    {ok,Fd} = ei_connect(P, node()),

    Fun1 = fun ei_send/1,
    Fun2 = fun(X) -> {P, X, Fd, Fun1} end,
    Bits = <<1,2,3:5>>,

    AMsg={Fun1,Fun2,Bits},
    %%AMsg={wait_with_funs, new_dist_format},
    ok = ei_send_funs(P, Fd, self(), AMsg),
    EIMsg = receive M -> M end,
    EIMsg = AMsg,

    runner:send_eot(P),
    runner:recv_eot(P),
    ok.

ei_reg_send(Config) when is_list(Config) ->
    P = runner:start(Config, ?interpret),
    0 = ei_connect_init(P, 42, erlang:get_cookie(), 0, get_group(Config)),
    {ok,Fd} = ei_connect(P, node()),

    ARegName = a_strange_registred_name,
    register(ARegName, self()),
    ok = ei_reg_send(P, Fd, ARegName, AMsg={another,[strange],message}),
    receive AMsg -> ok end,

    runner:send_eot(P),
    runner:recv_eot(P),
    ok.

ei_threaded_send(Config) when is_list(Config) ->
    Einode = filename:join(proplists:get_value(data_dir, Config), "einode"),
    N = 15,
    Host = atom_to_list(node()),
    TestServerPid = self(),
    [ spawn_link(fun() -> rec_einode(I, TestServerPid) end)
      || I <- lists:seq(0, N-1) ],
    [ receive {I,registered} -> ok end
      || I <- lists:seq(0, N-1) ],
    spawn_link(fun() -> start_einode(Einode, N, Host) end),
    [ receive I -> ok end
      || I <- lists:seq(0, N-1) ],
    ok.

rec_einode(N, TestServerPid) ->
    Regname = list_to_atom("mth"++integer_to_list(N)),
    register(Regname, self()),
    TestServerPid ! {N, registered},
    io:format("~p waiting~n", [Regname]),
    receive
        X ->
            io:format("Received by ~s ~p~n", [Regname, X]),
            TestServerPid ! N,
            X
    after 10000 ->
              ct:fail(Regname)
    end.

start_einode(Einode, N, Host) ->
    Einodecmd = Einode ++ " " ++ atom_to_list(erlang:get_cookie())
    ++ " " ++ integer_to_list(N) ++ " " ++ Host,
    io:format("Einodecmd  ~p ~n", [Einodecmd]),      
    open_port({spawn, Einodecmd}, []),
    ok.

ei_rpc(Config) when is_list(Config) ->
    P = runner:start(Config, ?interpret),
    0 = ei_connect_init(P, 42, erlang:get_cookie(), 0, get_group(Config)),
    {ok,Fd} = ei_connect(P, node()),

    S= "Hej du glade!", SRev = lists:reverse(S),
    X = ei_rpc(P, Fd, self(), {?MODULE, rpc_test}, [SRev]),
    {term, S}= X,

    runner:send_eot(P),
    runner:recv_eot(P),
    ok.

ei_set_get_tracelevel(Config) when is_list(Config) ->
    P = runner:start(Config, ?interpret),
    5 = ei_set_get_tracelevel(P, 5),
    0 = ei_connect_init(P, 42, erlang:get_cookie(), 0, get_group(Config)),
    {ok,Fd} = ei_connect(P, node()),

    S= "Hej du glade!", SRev = lists:reverse(S),
    X = ei_rpc(P, Fd, self(), {?MODULE, rpc_test}, [SRev]),
    {term, S}= X,

    0 = ei_set_get_tracelevel(P, 0),

    runner:send_eot(P),
    runner:recv_eot(P),
    ok.


ei_connect_host_port_test(Config) when is_list(Config) ->
    P = runner:start(Config, ?interpret),
    0 = ei_connect_init(P, 42, erlang:get_cookie(), 0, default),
    [NodeName, Hostname] = string:lexemes(atom_to_list(node()), "@"),
    {ok, NamePortList} = net_adm:names(),
    {value, {_, Port}}
        = lists:search(fun({N, _}) ->
                               string:equal(N, NodeName)
                       end,
                       NamePortList),
    {ok,Fd} = ei_connect_host_port(P,
                                   erlang:list_to_atom(Hostname),
                                   Port),
    ok = ei_send(P, Fd, self(), AMsg={a,message}),
    receive AMsg -> ok end,

    runner:send_eot(P),
    runner:recv_eot(P),
    ok.

%% Should be moved to another suite...
ei_make_ref(Config) when is_list(Config) ->
    P = runner:start(Config, ?interpret),
    0 = ei_connect_init(P, 42, erlang:get_cookie(), 0, default),
    {ok,Fd} = ei_connect(P, node()),

    CNode = hd(nodes(hidden)),
    io:format("CNode = ~p", [CNode]),

    N = (1 bsl 18)+1,
    Refs = make_refs(N, CNode, P, Fd, []),
    io:format("Last Ref ~p~n", [hd(Refs)]),
    N = length(lists:usort(Refs)),

    runner:send_eot(P),
    runner:recv_eot(P),
    ok.

make_refs(0, _CNode, _P, _Fd, Refs) ->
    Refs;
make_refs(N, CNode, P, Fd, Refs) ->
    ok = ei_make_ref(P, Fd, self()),
    receive
        Ref ->
            true = is_reference(Ref),
            CNode = node(Ref),
            make_refs(N-1, CNode, P, Fd, [Ref|Refs])
    end.


%%% Interface functions for ei (erl_interface) functions.

ei_connect_init(P, Num, Cookie, Creation, SockImpl) ->
    send_command(P, ei_connect_init, [Num,Cookie,Creation,SockImpl]),
    case get_term(P) of
        {term,Int} when is_integer(Int) -> Int
    end.

ei_connect(P, Node) ->
    send_command(P, ei_connect, [Node]),
    case get_term(P) of
        {term,{Fd,_}} when Fd >= 0 -> {ok,Fd};
        {term,{-1,Errno}} -> {error,Errno}
    end.

ei_connect_host_port(P, Hostname, Port) ->
    send_command(P, ei_connect_host_port, [Hostname, Port]),
    case get_term(P) of
        {term,{Fd,_}} when Fd >= 0 -> {ok,Fd};
        {term,{-1,Errno}} -> {error,Errno}
    end.

ei_set_get_tracelevel(P, Tracelevel) ->
    send_command(P, ei_set_get_tracelevel, [Tracelevel]),
    case get_term(P) of
        {term,{tracelevel, Level}} when is_integer(Level) -> Level
    end.

ei_send(P, Fd, To, Msg) ->
    send_command(P, ei_send, [Fd,To,Msg]),
    get_send_result(P).

ei_format_pid(P, Fd, To) ->
    send_command(P, ei_format_pid, [Fd, To]),
    get_send_result(P).

ei_send_funs(P, Fd, To, Msg) ->
    send_command(P, ei_send_funs, [Fd,To,Msg]),
    get_send_result(P).

ei_reg_send(P, Fd, To, Msg) ->
    send_command(P, ei_reg_send, [Fd,To,Msg]),
    get_send_result(P).

ei_rpc(P, Fd, To, Func, Msg) ->
    send_command(P, ei_rpc, [Fd, To, Func, Msg]),
    get_term(P).

ei_make_ref(P, Fd, To) ->
    send_command(P, ei_make_ref, [Fd,To]),
    get_send_result(P).


get_send_result(P) ->
    case get_term(P) of
        {term,{0,_}} -> ok;
        {term,{1,_}} -> ok;
        {term,{-1,Errno}} -> {error,Errno};
        {term,{Res,Errno}}->
            io:format("Return value: ~p\nerl_errno: ~p", [Res,Errno]),
            ct:fail(bad_return_value)
    end.

send_command(P, Name, Args) ->
    runner:send_term(P, {Name,list_to_tuple(Args)}).

%%% Test function for RPC

rpc_test(S) ->    
    lists:reverse(S).
