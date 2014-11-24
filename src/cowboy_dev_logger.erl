-module(cowboy_dev_logger).

-export([execute/3]).

execute(Req, Env, Next) ->
  case cowboy_req:header(<<"upgrade">>, Req) of
    {<<"websocket">>, _} ->
      Next(Req, Env);
    _ ->
      print_time(Req, Env, Next)
  end.

print_time(Req, Env, Next) ->
  [Method, Path, Qs, OrigOnResponse] = cowboy_req:get([method, path, qs, onresponse], Req),
  OnResponse = gen_onresponse(OrigOnResponse),
  Req2 = cowboy_req:set([{onresponse, OnResponse}], Req),

  {Time, Res} = timer:tc(Next, [Req2, Env]),

  StatusCode = format_status_code(Res),
  ResSize = format_response_size(Res),

  Url = case Qs of
    <<>> -> Path;
    _ -> <<Path/binary, "?", Qs/binary>>
  end,

  io:format("\x1b[90m~s ~s \x1b[" ++ StatusCode ++ "\x1b[90m" ++ ResSize ++ "~s\x1b[0m~n", [Method, Url, format_time(Time)]),
  Res.

format_status_code({ok, Req3, _}) ->
  {S, _} = cowboy_req:meta(status_code, Req3, ""),
  pp_status_code(S);
format_status_code({halt, Req3}) ->
  {S, _} = cowboy_req:meta(status_code, Req3, ""),
  pp_status_code(S);
format_status_code(_) ->
  "".

pp_status_code(S) when is_integer(S) ->
  pp_status_code(integer_to_list(S) ++ " ");
pp_status_code(S = [$1|_]) ->
  "32m" ++ S;
pp_status_code(S = [$2|_]) ->
  "32m" ++ S;
pp_status_code(S = [$3|_]) ->
  "36m" ++ S;
pp_status_code(S = [$4|_]) ->
  "33m" ++ S;
pp_status_code(S = [$5|_]) ->
  "31m" ++ S;
pp_status_code("") ->
  "".

format_response_size({ok, Req, _}) ->
  {S, _} = cowboy_req:meta(response_length, Req, ""),
  pp_response_size(S);
format_response_size(_) ->
  "".

pp_response_size(S) when not is_integer(S) ->
  "";
pp_response_size(S) when S < 1000 ->
  integer_to_list(S) ++ "b ";
pp_response_size(S) ->
  integer_to_list(trunc(S/1000)) ++ "kb ".

gen_onresponse(undefined) ->
  fun (Status, Headers, Body, Req) ->
    {Status, Headers, set_meta(Status, Body, Req)}
  end;
gen_onresponse(Orig) ->
  fun(Status, Headers, Body, Req) ->
    case Orig(Status, Headers, Body, Req) of
      {S2, H2, Req2} ->
        {S2, H2, set_meta(Status, Body, Req2)};
      Req ->
        set_meta(Status, Body, Req)
    end
  end.

set_meta(Status, Body, Req) ->
  Req2 = cowboy_req:set_meta(status_code, Status, Req),
  cowboy_req:set_meta(response_length, iolist_size(Body), Req2).

format_time(Time) when Time < 1000 ->
  "\e[34m" ++ integer_to_list(trunc(Time)) ++ "us";
format_time(Time) when Time < 1000000 ->
  "\e[34m" ++ integer_to_list(trunc(Time/1000)) ++ "ms";
format_time(Time) ->
  "\e[35m" ++ integer_to_list(trunc(Time/1000000)) ++ "s".
