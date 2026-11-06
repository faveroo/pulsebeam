
-module(pulsebeam_http_server_ffi).

-export([start/1]).

start(Status) ->
    case gen_tcp:listen(
        0,
        [binary, {active, false}, {ip, {127, 0, 0, 1}}]
    ) of
        {ok, Listen} ->
            {ok, Port} = inet:port(Listen),

            spawn(fun() ->
                serve_once(Listen, Status)
            end),

            {ok, Port};

        {error, Reason} ->
            {error, atom_to_binary(Reason, utf8)}
    end.

serve_once(Listen, Status) ->
    case gen_tcp:accept(Listen, 2000) of
        {ok, Socket} ->
            case gen_tcp:recv(Socket, 0, 2000) of
                {ok, _Request} ->
                    Reason = case Status of
                        200 -> "OK";
                        503 -> "Service Unavailable";
                        _ -> "Test Response"
                    end,

                    Response = iolist_to_binary([
                        "HTTP/1.1 ",
                        integer_to_list(Status),
                        " ",
                        Reason,
                        "\r\n",
                        "Content-Type: text/plain\r\n",
                        "Content-Length: 2\r\n",
                        "Connection: close\r\n",
                        "\r\n",
                        "OK"
                    ]),

                    _ = gen_tcp:send(Socket, Response);

                _ ->
                    ok
            end,

            gen_tcp:close(Socket);

        _ ->
            ok
    end,

    gen_tcp:close(Listen).
