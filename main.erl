-module(main).
-export([start/0]).

-define(COOKIE, 'lenguajestup2026').

start() ->
    %% 1. Configurar la Cookie obligatoria según la especificación
    erlang:set_cookie(node(), ?COOKIE),

    %% 2. Iniciar el núcleo del chat (se registra como 'chat')
    ChatPid = chat_core:start(),

    %% 3. Iniciar el descubrimiento por rbeacon (UDP broadcast)
    rbeacon:start_link(ChatPid, ?COOKIE),

    %% 4. Iniciar la interfaz de consola con prompt interactivo
    chat_ui:start(),
    ok.