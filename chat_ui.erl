-module(chat_ui).
-export([start/0]).

start() ->
    spawn(fun() -> prompt_loop() end).

prompt_loop() ->
    io:format("~n=== Bienvenido al Chat Distribuido ===~n"),
    UserName = get_non_empty_line("Ingresa tu nombre de usuario: "),
    io:format("Listo, ~s. Podes escribir mensajes. Escribi '/salir' para terminar.~n> ", [UserName]),
    input_loop(UserName).

input_loop(UserName) ->
    case io:get_line("") of
        eof ->
            ok;
        {error, _} ->
            ok;
        RawLine ->
            Line = clean_line(RawLine),
            case Line of
                "/salir" ->
                    io:format("Saliendo del chat...~n"),
                    init:stop();
                "" ->
                    io:format("> "),
                    input_loop(UserName);
                Message ->
                    chat_core:send_message(UserName, Message),
                    io:format("> "),
                    input_loop(UserName)
            end
    end.

get_non_empty_line(Prompt) ->
    case io:get_line(Prompt) of
        eof -> "Anonimo";
        {error, _} -> "Anonimo";
        Raw ->
            Clean = clean_line(Raw),
            case Clean of
                "" -> get_non_empty_line(Prompt);
                Valid -> Valid
            end
    end.

%% Limpia espacios y saltos de linea sin crashear
clean_line(Str) ->
    string:strip(string:strip(Str, both, $\n), both, $\r).