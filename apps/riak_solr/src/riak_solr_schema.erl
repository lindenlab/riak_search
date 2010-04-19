-module(riak_solr_schema, [Name, Version, Fields]).

-include_lib("riak_solr/include/riak_solr.hrl").

-export([name/0, version/0, fields/0, find_field/1]).
-export([validate_commands/1]).

name() ->
    Name.

version() ->
    Version.

fields() ->
    Fields().

find_field(FName) ->
    case [F || F <- Fields,
               F#riak_solr_field.name =:= FName] of
        [] ->
            undefined;
        [Field] ->
            Field
    end.

validate_commands(Doc) ->
    DName = proplists:get_value(index, Doc),
    case DName =:= Name of
        true ->
            Required = [F || F <- Fields,
                             F#riak_solr_field.required =:= true],
            Optional = [F || F <- Fields,
                             F#riak_solr_field.required =:= false],
            validate_docs(proplists:get_value(docs, Doc), Required, Optional, []);
        false ->
            {error, {bad_schema_name, DName}}
    end.

%% Internal functions
validate_docs([], _Reqd, _Optional, Accum) ->
    {ok, lists:reverse(Accum)};
validate_docs([H|T], Reqd, Optional, Accum) ->
    case verify_required(H, Reqd) of
        {ok, H1} ->
            case verify_optional(H1, Optional) of
                {ok, H2} ->
                    validate_docs(T, Reqd, Optional, [H2|Accum]);
                Error ->
                    Error
            end;
        Error ->
            Error
    end.

verify_required(Doc, []) ->
    {ok, Doc};
verify_required(Doc, [H|T]) ->
    case dict:find(H#riak_solr_field.name, Doc) of
        {ok, FieldValue} ->
            Doc1 = dict:store(H#riak_solr_field.name, convert_types(FieldValue,
                                                                    H#riak_solr_field.type), Doc),
            verify_required(Doc1, T);
        _ ->
            {error, {reqd_field_missing, H#riak_solr_field.name}}
    end.

verify_optional(Doc, []) ->
    {ok, Doc};
verify_optional(Doc, [H|T]) ->
    case dict:find(H#riak_solr_field.name, Doc) of
        {ok, FieldValue} ->
            Doc1 = dict:store(H#riak_solr_field.name, convert_types(FieldValue,
                                                                    H#riak_solr_field.type), Doc),
            verify_optional(Doc1, T);
        _ ->
            verify_optional(Doc, T)
    end.

convert_types(FieldValue, string) ->
    FieldValue;
convert_types("true", boolean) ->
    true;
convert_types("false", boolean) ->
    false;
convert_types("yes", boolean) ->
    true;
convert_types("no", boolean) ->
    false;
convert_types(FieldValue, integer) ->
    list_to_integer(FieldValue);
convert_types(FieldValue, float) ->
    list_to_float(FieldValue).