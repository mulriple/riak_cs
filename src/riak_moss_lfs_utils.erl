>%% -------------------------------------------------------------------
%%
%% Copyright (c) 2007-2011 Basho Technologies, Inc.  All Rights Reserved.
%%
%% -------------------------------------------------------------------


-module(riak_moss_lfs_utils).

-include("riak_moss.hrl").

-export([is_manifest/1,
         remove_block/2,
         still_waiting/1,
         block_count/1,
         block_name/3,
         block_name_to_term/1,
         initial_blocks/1,
         sorted_blocks_remaining/1,
         block_keynames/3,
         riak_connection/0,
         riak_connection/2]).

%% @doc Returns true if Value is
%%      a manifest record
is_manifest(Value) ->
    is_record(Value, lfs_manifest).

%% @doc Remove a chunk from the
%%      blocks_remaining field of Manifest
remove_block(Manifest, Chunk) ->
    Remaining = Manifest#lfs_manifest.blocks_remaining,
    Updated = sets:del_element(Chunk, Remaining),
    Manifest#lfs_manifest{blocks_remaining=Updated}.

%% @doc Return true or false
%%      depending on whether
%%      we're still waiting
%%      to accumulate more chunks
still_waiting(#lfs_manifest{blocks_remaining=Remaining}) ->
    sets:size(Remaining) =/= 0.

%% @doc A set of all of the blocks that
%%      make up the file.
initial_blocks(ContentLength) ->
    UpperBound = block_count(ContentLength),
    Seq = lists:seq(0, (UpperBound - 1)),
    sets:from_list(Seq).

block_name(Key, UUID, Number) ->
    term_to_binary({Key, UUID, Number}).

block_name_to_term(Name) ->
    binary_to_term(Name).

%% @doc The number of blocks that this
%%      size will be broken up into
block_count(ContentLength) ->
    block_count(ContentLength, ?LFS_BLOCK_SIZE).

block_count(ContentLength, BlockSize) ->
    Quotient = ContentLength div BlockSize,
    case ContentLength rem BlockSize of
        0 ->
            Quotient;
        _ ->
            Quotient + 1
    end.

set_to_sorted_list(Set) ->
    lists:sort(sets:to_list(Set)).

sorted_blocks_remaining(#lfs_manifest{blocks_remaining=Remaining}) ->
    set_to_sorted_list(Remaining).

block_keynames(KeyName, UUID, BlockList) ->
    MapFun = fun(BlockSeq) ->
        block_name(KeyName, UUID, BlockSeq) end,
    lists:map(MapFun, BlockList).

%% @doc Get a protobufs connection to the riak cluster
%% using information from the application environment.
-spec riak_connection() -> {ok, pid()} | {error, term()}.
riak_connection() ->
    case application:get_env(riak_moss, riak_ip) of
        {ok, Host} ->
            ok;
        undefined ->
            Host = "127.0.0.1"
    end,
    case application:get_env(riak_moss, riak_pb_port) of
        {ok, Port} ->
            ok;
        undefined ->
            Port = 8087
    end,
    riak_connection(Host, Port).

%% @doc Get a protobufs connection to the riak cluster.
-spec riak_connection(string(), pos_integer()) -> {ok, pid()} | {error, term()}.
riak_connection(Host, Port) ->
    riakc_pb_socket:start_link(Host, Port).
