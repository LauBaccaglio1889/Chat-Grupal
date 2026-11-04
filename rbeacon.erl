-module(rbeacon).
-export([start_link/2]).

-define(PORT, 8000).
-define(INTERVAL, 1000).

start_link(CallbackPid, Cookie) ->
    spawn_link(fun() -> init(CallbackPid, Cookie) end).

init(CallbackPid, Cookie) ->
    %% Opciones con reuseport/reuseaddr para permitir multiples instancias locales
    ListenOpts = [
        binary,
        {active, true},
        {broadcast, true},
        {reuseaddr, true}
    ],
    
    %% Intentar abrir en el puerto 8000
    SocketRes = case gen_udp:open(?PORT, ListenOpts) of
        {ok, Sock} ->
            {ok, Sock, Sock};
        {error, eaddrinuse} ->
            %% Si otra instancia ya bloqueo el bind del puerto en Windows,
            %% se abre un socket emisor efímero y se reintenta escuchar
            case gen_udp:open(0, [binary, {broadcast, true}]) of
                {ok, SendSock} -> {client_only, SendSock};
                Err -> Err
            end;
        Error ->
            Error
    end,

    case SocketRes of
        {ok, InSocket, OutSocket} ->
            erlang:send_after(?INTERVAL, self(), broadcast),
            loop(InSocket, OutSocket, CallbackPid, Cookie);
        {client_only, OutSocket} ->
            io:format("[rbeacon] Puerto en uso por otro nodo local; operando en modo emisor.~n"),
            erlang:send_after(?INTERVAL, self(), broadcast),
            loop(undefined, OutSocket, CallbackPid, Cookie);
        {error, Reason} ->
            io:format("[rbeacon] Error abriendo socket UDP: ~p~n", [Reason]),
            exit(Reason)
    end.

loop(InSocket, OutSocket, CallbackPid, Cookie) ->
    receive
        broadcast ->
            %% El anuncio lleva el nombre del nodo para que otras PCs puedan conectarse
            NodeBin = atom_to_binary(node(), utf8),
            _ = gen_udp:send(OutSocket, {255, 255, 255, 255}, ?PORT, <<"announcement:", NodeBin/binary>>),
            erlang:send_after(?INTERVAL, self(), broadcast),
            loop(InSocket, OutSocket, CallbackPid, Cookie);

        {udp, InSocket, IP, _InPortNo, <<"announcement:", NodeBin/binary>>} ->
            CallbackPid ! {beacon_seen, IP, NodeBin},
            loop(InSocket, OutSocket, CallbackPid, Cookie);

        %% Formato viejo, sin nombre de nodo
        {udp, InSocket, IP, _InPortNo, <<"announcement">>} ->
            CallbackPid ! {beacon_seen, IP},
            loop(InSocket, OutSocket, CallbackPid, Cookie);

        stop ->
            case InSocket of
                undefined -> ok;
                _ -> gen_udp:close(InSocket)
            end,
            gen_udp:close(OutSocket);

        _Other ->
            loop(InSocket, OutSocket, CallbackPid, Cookie)
    end.