-module(chat_core).
-export([start/0, send_message/2, get_peers/0]).

-define(TIMEOUT_SECS, 15).
-define(CHECK_INTERVAL, 2000).

start() ->
    Pid = spawn(fun() -> init() end),
    register(chat, Pid),
    Pid.

send_message(User, Content) ->
    chat ! {outgoing, User, Content},
    ok.

get_peers() ->
    chat ! {get_peers, self()},
    receive
        {peers, Peers} -> Peers
    after 1000 -> []
    end.

init() ->
    erlang:send_after(?CHECK_INTERVAL, self(), cleanup_peers),
    loop(#{}).

loop(Peers) ->
    receive
        %% Mensaje entrante de otro nodo
        {incoming, Usuario, Contenido} ->
            io:format("~n[~s]: ~s~n> ", [Usuario, Contenido]),
            loop(Peers);

        %% Mensaje enviado desde la consola local
        {outgoing, Usuario, Contenido} ->
            SelfNode = node(),
            DestNodes = lists:usort(nodes() ++ maps:keys(Peers)),
            lists:foreach(
                fun(Node) when Node =/= SelfNode ->
                    {chat, Node} ! {incoming, Usuario, Contenido};
                   (_) ->
                    ok
                end,
                DestNodes
            ),
            loop(Peers);

        %% Señal recibida desde rbeacon
        {beacon_seen, IP} ->
            Now = erlang:system_time(second),
            %% Intentar descubrir y conectar con nodos locales/remotos
            try_connect(IP),
            Connected = nodes(),
            NewPeers = lists:foldl(fun(N, Acc) -> maps:put(N, Now, Acc) end, Peers, Connected),
            loop(NewPeers);

        %% Timeout de 15 segundos: descartar caídos
        cleanup_peers ->
            Now = erlang:system_time(second),
            %% Auto-ping a los ya conectados para mantener el mapa actualizado
            lists:foreach(fun(N) -> net_adm:ping(N) end, nodes()),
            ActivePeers = maps:filter(
                fun(_Node, LastSeen) -> (Now - LastSeen) =< ?TIMEOUT_SECS end,
                Peers
            ),
            erlang:send_after(?CHECK_INTERVAL, self(), cleanup_peers),
            loop(ActivePeers);

        {get_peers, From} ->
            From ! {peers, maps:keys(Peers)},
            loop(Peers);

        _Other ->
            loop(Peers)
    end.

%% Intenta conectarse a los nodos según el entorno
try_connect(_IP) ->
    Host = get_host(),
    %% Probar los nombres habituales en la misma máquina
    Candidates = [
        list_to_atom("nodo1@" ++ Host),
        list_to_atom("nodo2@" ++ Host),
        list_to_atom("nodo3@" ++ Host),
        list_to_atom("chat@" ++ Host)
    ],
    lists:foreach(
        fun(Target) when Target =/= node() ->
            net_adm:ping(Target);
           (_) ->
            ok
        end,
        Candidates
    ).

get_host() ->
    NodeStr = atom_to_list(node()),
    case string:tokens(NodeStr, "@") of
        [_Name, Host] -> Host;
        _ -> "localhost"
    end.