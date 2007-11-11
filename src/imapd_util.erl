%%%---------------------------------------------------------------------------------------
%%% @author     Stuart Jackson <sjackson@simpleenigma.com> [http://erlsoft.org]
%%% @copyright  2006 - 2007 Simple Enigma, Inc. All Rights Reserved.
%%% @doc        IMAP server utility functions
%%% @reference  See <a href="http://erlsoft.org/modules/erlmail" target="_top">Erlang Software Framework</a> for more information
%%% @version    0.0.6
%%% @since      0.0.6
%%% @end
%%%
%%%
%%% The MIT License
%%%
%%% Copyright (c) 2007 Stuart Jackson, Simple Enigma, Inc. All Righs Reserved
%%%
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"), to deal
%%% in the Software without restriction, including without limitation the rights
%%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%% copies of the Software, and to permit persons to whom the Software is
%%% furnished to do so, subject to the following conditions:
%%%
%%% The above copyright notice and this permission notice shall be included in
%%% all copies or substantial portions of the Software.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%%% THE SOFTWARE.
%%%
%%%
%%%---------------------------------------------------------------------------------------
-module(imapd_util).
-author('sjackson@simpleenigma.com').
-include("../include/imap.hrl").
-include("../include/erlmail.hrl").


-export([clean/1]).
-export([flags_resp/1,flags_resp/2]).
-export([greeting/1,greeting_capability/1]).
-export([heirachy_char/0,inbox/1]).
-export([mailbox_info/1,mailbox_info/2,mailbox_info/3]).
-export([out/2,out/3,send/2]).
-export([parse/1,parse_addresses/1]).
-export([quote/1,quote/2,unquote/1]).
-export([response/1,re_split/1,re_split/4]).
-export([split_at/1,split_at/2]).
-export([status_flags/1,status_resp/1,status_info/2]).
-export([seq_to_list/1,list_to_seq/1]).

%%-------------------------------------------------------------------------
%% @spec clean(String::string()) -> string()
%% @doc Removes whitespace and Doule Quotes from a string.
%% @end
%%-------------------------------------------------------------------------
clean({UserName,Password}) ->
	{clean(UserName),clean(Password)};

clean(String) ->
	S = string:strip(String,both,32),
	S2 = string:strip(S,both,34),
	string:strip(S2,both,32).

%%-------------------------------------------------------------------------
%% @spec flags_resp(list()) -> string()
%% @doc Takes a list of flags and returns a response string.
%% @end
%%-------------------------------------------------------------------------
flags_resp([]) -> "()";
flags_resp(List) -> flags_resp(List,[]).
%%-------------------------------------------------------------------------
%% @spec flags_resp(list(),list()) -> string()
%% @hidden
%% @end
%%-------------------------------------------------------------------------
flags_resp([H|T],Acc) when is_atom(H) ->
	flags_resp(T,[http_util:to_upper(atom_to_list(H)),92,32|Acc]);
flags_resp([],Acc) -> "(" ++ string:strip(lists:flatten(lists:reverse(Acc))) ++ ")".

%%-------------------------------------------------------------------------
%% @spec greeting(Options::list()) -> string()
%% @doc Returns IMAP greeting string from config file or uses Default.
%% @end
%%-------------------------------------------------------------------------
greeting(State) when is_record(State,imapd_fsm) -> greeting(State#imapd_fsm.options);
greeting(Options) ->
	case erlmail_conf:lookup(server_imap_greeting,Options) of
		[] -> "ErlMail IMAP4 Server ready";
		Greeting -> Greeting
	end.

%%-------------------------------------------------------------------------
%% @spec (Options::list()) -> string()
%% @doc Check if capability data should be returned in greeting. 
%%      Default: false
%% @end
%%-------------------------------------------------------------------------
greeting_capability(State) when is_record(State,imapd_fsm) -> greeting_capability(State#imapd_fsm.options);
greeting_capability(Options) ->
	case erlmail_conf:lookup_atom(server_imap_greeting_capability,Options) of
		true -> true;
		_ -> false
	end.

%%-------------------------------------------------------------------------
%% @spec () -> string()
%% @doc Gets Heirarchy chara from config file.
%%      Default: "/"
%% @end
%%-------------------------------------------------------------------------
heirachy_char() ->
	case erlmail_conf:lookup(server_imap_hierarchy) of
		[] -> "/";
		Heirarchy -> Heirarchy
	end.

%%-------------------------------------------------------------------------
%% @spec (MailBoxName::string()) -> string()
%% @doc Make sure that the string INBOX is always capitalized at the 
%%      begining of the mailbox name
%% @todo work with longer mailbox names that start with INBOX
%% @end
%%-------------------------------------------------------------------------

inbox(MailBoxName) ->
	case list_to_atom(http_util:to_lower(MailBoxName)) of
		inbox -> "INBOX";
		_ -> MailBoxName
	end.

%%-------------------------------------------------------------------------
%% @spec (List::list()) -> string()
%% @doc Converts a list of integers into an IMAP sequence
%% @end
%%-------------------------------------------------------------------------
list_to_seq(List) -> list_to_seq(List,0,[]).

%%-------------------------------------------------------------------------
%% @spec (list(),integer(),list()) -> string()
%% @hidden
%% @end
%%-------------------------------------------------------------------------
list_to_seq([],_,Acc) -> lists:flatten(lists:reverse(Acc));
list_to_seq([H],Start,Acc) when is_integer(H), Start > 0 ->
	String = integer_to_list(Start) ++ ":" ++ integer_to_list(H),
	list_to_seq([],0,[String|Acc]);
list_to_seq([H],_,Acc) when is_integer(H) ->
	list_to_seq([],0,[integer_to_list(H)|Acc]);
list_to_seq([H|[I|_] = T],Start,Acc) when H == I - 1, Start == 0 ->
	list_to_seq(T,H,Acc);
list_to_seq([H|[I] = _T],Start,Acc) when H == I - 1, is_integer(I) ->
	?D({Start,H,I}),
	String = integer_to_list(Start) ++ ":" ++ integer_to_list(I),
	list_to_seq([],Start,[String|Acc]);
list_to_seq([H|[I|_J] = T],Start,Acc) when H == I - 1 ->
	list_to_seq(T,Start,Acc);
list_to_seq([H|[I|_J] = T],Start,Acc) when H /= I - 1, Start > 0 ->
	String = integer_to_list(Start) ++ ":" ++ integer_to_list(H),
	list_to_seq(T,0,[44,String|Acc]);
list_to_seq([H|[_I|_] = T],_Start,Acc) ->
	list_to_seq(T,0,[44,integer_to_list(H)|Acc]).




%%-------------------------------------------------------------------------
%% @spec (tuple()) -> tuple()
%% @doc Takes a #mailbox_store{} record and returns all information in a 
%%      #mailbox{} record
%% @end
%%-------------------------------------------------------------------------
mailbox_info(MailBoxStore) -> mailbox_info(MailBoxStore,all).

%%-------------------------------------------------------------------------
%% @spec (tuple(),Flags::list()) -> tuple()
%% @doc Takes a #mailbox_store{} record and returns information from Flags
%%      in a #mailbox{} record
%% @end
%%-------------------------------------------------------------------------
mailbox_info(MailBoxStore,Args) when is_record(MailBoxStore,mailbox_store) -> 
	{MailBoxName,UserName,DomainName} = MailBoxStore#mailbox_store.name,
	mailbox_info(#mailbox{name = MailBoxName},{UserName,DomainName},Args);
mailbox_info(MailBox,{UserName,DomainName}) -> mailbox_info(MailBox,{UserName,DomainName},all).
%%-------------------------------------------------------------------------
%% @spec (tuple(),tuple(),Flags::list()) -> tuple()
%% @hidden
%% @end
%%-------------------------------------------------------------------------

mailbox_info(MailBox,{UserName,DomainName},all) -> mailbox_info(MailBox,{UserName,DomainName},[exists,messages,unseen,recent,flags,permanentflags]);

mailbox_info(MailBox,{UserName,DomainName},[exists|T]) ->
	Store = erlmail_conf:lookup_atom(store_type_message),
	case Store:select({MailBox#mailbox.name,{UserName,DomainName}}) of
		[] -> mailbox_info(MailBox,{UserName,DomainName},T);
		MailBoxStore -> mailbox_info(MailBox#mailbox{exists=length(MailBoxStore#mailbox_store.messages)},{UserName,DomainName},T)
	end;
mailbox_info(MailBox,{UserName,DomainName},[messages|T]) ->
	Store = erlmail_conf:lookup_atom(store_type_message),
	case Store:select({MailBox#mailbox.name,{UserName,DomainName}}) of
		[] -> mailbox_info(MailBox,{UserName,DomainName},T);
		MailBoxStore -> mailbox_info(MailBox#mailbox{messages=length(MailBoxStore#mailbox_store.messages)},{UserName,DomainName},T)
	end;
mailbox_info(MailBox,{UserName,DomainName},[unseen|T]) ->
	Store = erlmail_conf:lookup_atom(store_type_message),
	case Store:unseen({MailBox#mailbox.name,UserName,DomainName}) of
		{_Seen,Unseen} ->  mailbox_info(MailBox#mailbox{unseen=length(Unseen)},{UserName,DomainName},T);
		_ -> mailbox_info(MailBox,{UserName,DomainName},T)
	end;
mailbox_info(MailBox,{UserName,DomainName},[recent|T]) ->
	Store = erlmail_conf:lookup_atom(store_type_message),
	case Store:recent({MailBox#mailbox.name,UserName,DomainName}) of
		Recent when is_list(Recent) ->  mailbox_info(MailBox#mailbox{recent=length(Recent)},{UserName,DomainName},T);
		_ -> mailbox_info(MailBox,{UserName,DomainName},T)
	end;
mailbox_info(MailBox,{UserName,DomainName},[flags|T]) ->
	mailbox_info(MailBox#mailbox{flags=[answered,flagged,draft,deleted,seen]},{UserName,DomainName},T);
% @todo UIDNEXT
% @todo UIDVALIDITY


mailbox_info(MailBox,{UserName,DomainName},[_H|T]) ->
	?D(_H),
	mailbox_info(MailBox,{UserName,DomainName},T);

mailbox_info(MailBox,{_UserName,_DomainName},[]) -> MailBox.


%%-------------------------------------------------------------------------
%% @hidden
%% @end
%%-------------------------------------------------------------------------
out(Command,State) -> io:format("~p ~p~n",[State#imapd_fsm.addr,Command]).
%%-------------------------------------------------------------------------
%% @hidden
%% @end
%%-------------------------------------------------------------------------
out(Command,Param,State) -> io:format("~p ~p ~p~n",[State#imapd_fsm.addr,Command,Param]).

%%-------------------------------------------------------------------------
%% @spec parse(Line::string()) -> imap_cmd()
%% @type imap_cmd() = {imap_cmd,line(),tag(),comamnd(),cmd_data()}
%% @type line() = string()
%% @type command() = atom()
%% @type tag() = atom()
%% @type cmd_data() = term()
%% @doc Takes a command line from the connected IMAP client and parses the 
%%      it into an imap_cmd{} record
%% @todo parse DATA differently depending on command
%% @end
%%-------------------------------------------------------------------------

parse(Line) ->
	case split_at(Line,32) of
		{Tag,[]} -> 
			Command = [],
			Data = [];
		{Tag,Rest} ->
			case split_at(Rest,32) of
				{Command,[]} ->
					Data = [];
				{Command,Data} -> ok
			end
	end,
	NextData = case list_to_atom(string:strip(http_util:to_lower(Command))) of
		Cmd = login       -> clean(split_at(Data,32));
		Cmd = select      -> clean(inbox(Data));
		Cmd = create      -> clean(inbox(Data));
		Cmd = delete      -> clean(inbox(Data));
		Cmd = rename      -> 
			{Src,Dst} = re_split(Data),
			{clean(Src),clean(Dst)};
		Cmd = subscribe   -> clean(inbox(Data));
		Cmd = unsubscribe -> clean(inbox(Data));
		Cmd = status      -> 
			{MailBox,Flags} = re_split(Data),
			{clean(inbox(MailBox)),Flags};
		Cmd = store      -> 
			{Seq,FlagData} = imapd_util:split_at(Data),
			{Action,Flags} = imapd_util:split_at(FlagData),
			{Seq,Action,Flags};
		Cmd = list       -> 
			{Ref,MailBox} = re_split(Data),
			{Ref,clean(MailBox)};
		Cmd = lsub       -> 
			{Ref,MailBox} = re_split(Data),
			{Ref,clean(MailBox)};
		Cmd = fetch      -> 
			{Seq,NameString} = clean(split_at(Data)),
			{seq_to_list(Seq),imapd_fetch:tokens(NameString)};
		Cmd = uid        -> 
			{TypeString,Args} = clean(split_at(Data)),
			Type = list_to_atom(http_util:to_lower(TypeString)),
			case Type of
				fetch -> 
					{Seq,MessageData} = clean(split_at(Args)),
					{fetch,seq_to_list(Seq),imapd_fetch:tokens(MessageData)};
				copy  -> {copy,Args};
				store -> {store,Args}
			end;
		Cmd              -> Data
	end,
	#imap_cmd{
		line = Line,
		tag  = list_to_atom(string:strip(Tag)),
		cmd  = Cmd,
		data = NextData}.




parse_addresses(String) -> parse_addresses(string:tokens(String,[44]),[]).

parse_addresses([],Acc) -> lists:reverse(Acc);
parse_addresses([H|T],Acc) ->
	case regexp:split(H,"[<>@\"]") of
		{ok,[_,PersonalName,MailBoxName,HostName,_]} -> 
			parse_addresses(T,[#address{addr_name=PersonalName, addr_mailbox = MailBoxName, addr_host = HostName}|Acc]);
		{ok,[_,PersonalName,_,MailBoxName,HostName,_]} -> 
			parse_addresses(T,[#address{addr_name=PersonalName, addr_mailbox = MailBoxName, addr_host = HostName}|Acc]);
		{ok,[_,MailBoxName,HostName,_]} -> 
			parse_addresses(T,[#address{addr_mailbox = MailBoxName, addr_host = HostName}|Acc]);
		{ok,[MailBoxName,HostName]} -> 
			parse_addresses(T,[#address{addr_mailbox = MailBoxName, addr_host = HostName}|Acc]);
		{error,Reason} -> {error,Reason};
		Other -> Other
	end.






















%%-------------------------------------------------------------------------
%% @spec (String::string()) -> string()
%% @doc Determines if the given string needs to have Double Quotes
%%      around it or not
%% @end
%%-------------------------------------------------------------------------

quote([]) -> [34,34];
quote(String) -> quote(String,optional).

%%-------------------------------------------------------------------------
%% @spec (String::string(),Options::quoteoptions()) -> string()
%% @type quoteoptions() = true | false | optional
%% @doc Determines if the given string needs to have Double Quotes
%%      around it or not based on the given options. Default = false
%% @end
%%-------------------------------------------------------------------------
quote(Atom,Boolean) when is_atom(Atom) -> quote(atom_to_list(Atom),Boolean);
quote(String,true)     -> [34] ++ String ++ [34];
quote(String,optional) -> 
	case string:chr(String,32) of
		0 -> String;
		_ -> [34] ++ String ++ [34]
	end;
quote(String,false)    -> String;
quote(String,_UnKnown) -> String.

%%-------------------------------------------------------------------------
%% @spec response(imap_resp()) -> string()
%% @type imap_resp() = {imap_resp,record}
%% @doc Take an #imap_resp{} record and returns a response string
%% @end
%%-------------------------------------------------------------------------
response(Resp) when is_record(Resp,imap_resp) -> response(Resp,[]).
%%-------------------------------------------------------------------------
%% @spec response(imap_resp(),list()) -> string()
%% @hidden
%% @end
%%-------------------------------------------------------------------------
%% TAG
response(#imap_resp{_ = []} = _Resp,Acc) -> string:strip(lists:flatten(lists:reverse(Acc)));
response(#imap_resp{tag = Tag} = Resp,Acc) when is_atom(Tag), Tag /= [] -> 
	response(Resp#imap_resp{tag = []},[32,atom_to_list(Tag)|Acc]);
response(#imap_resp{tag = Tag} = Resp,Acc) when is_list(Tag), Tag /= [] -> 
	response(Resp#imap_resp{tag = []},[32,Tag|Acc]);
%% STATUS
response(#imap_resp{status = Status} = Resp,Acc) when is_atom(Status), Status /= [] -> 
	response(Resp#imap_resp{status = []},[32,http_util:to_upper(atom_to_list(Status))|Acc]);
response(#imap_resp{status = Status} = Resp,Acc) when is_list(Status), Status /= [] -> 
	response(Resp#imap_resp{status = []},[32,http_util:to_upper(Status)|Acc]);
response(#imap_resp{status = Status} = Resp,Acc) when is_integer(Status), Status /= [] -> 
	response(Resp#imap_resp{status = []},[32,integer_to_list(Status)|Acc]);
%% CODE
response(#imap_resp{code = {capability,Capability}} = Resp,Acc) ->
	response(Resp#imap_resp{code = []},[32,93,Capability,91|Acc]);
response(#imap_resp{code = {unseen,UnSeen}} = Resp,Acc) ->
	response(Resp#imap_resp{code = []},[32,93,integer_to_list(UnSeen),32,"UNSEEN",91|Acc]);
response(#imap_resp{code = {uidvalidity,UIDValidity}} = Resp,Acc) ->
	response(Resp#imap_resp{code = []},[32,93,integer_to_list(UIDValidity),32,"UIDVALIDITY",91|Acc]);
response(#imap_resp{code = {uidnext,UIDNext}} = Resp,Acc) ->
	response(Resp#imap_resp{code = []},[32,93,integer_to_list(UIDNext),32,"UIDNEXT",91|Acc]);
response(#imap_resp{code = {permanentflags,PermanentFlags}} = Resp,Acc) ->
	response(Resp#imap_resp{code = []},[32,93,flags_resp(PermanentFlags),32,"PERMANENTFLAGS",91|Acc]);
response(#imap_resp{code = 'read-write'} = Resp,Acc) ->
	response(Resp#imap_resp{code = []},[32,93,"READ-WRITE",91|Acc]);
response(#imap_resp{code = 'read-only'} = Resp,Acc) ->
	response(Resp#imap_resp{code = []},[32,93,"READ-ONLY",91|Acc]);
response(#imap_resp{code = Code} = Resp,Acc) when is_list(Code), Code /= [] ->
	response(Resp#imap_resp{code = []},[32,93,[],91|Acc]);
%% CMD
response(#imap_resp{cmd = Cmd} = Resp,Acc) when is_atom(Cmd), Cmd /= [] -> 
	response(Resp#imap_resp{cmd = []},[32,http_util:to_upper(atom_to_list(Cmd))|Acc]);
response(#imap_resp{cmd = Cmd} = Resp,Acc) when is_list(Cmd), Cmd /= [] -> 
	response(Resp#imap_resp{cmd = []},[32,http_util:to_upper(Cmd)|Acc]);
%% DATA
response(#imap_resp{data = {flags,Flags}} = Resp,Acc) ->
	response(Resp#imap_resp{data = []},[32,flags_resp(Flags)|Acc]);
response(#imap_resp{data = {status,MailBoxName,Info}} = Resp,Acc) ->
	response(Resp#imap_resp{data = []},[32,status_resp(Info),32,MailBoxName|Acc]);
response(#imap_resp{data = {list,Flags}} = Resp,Acc) ->
	Data = flags_resp(Flags),
	response(Resp#imap_resp{data = []},[32,Data|Acc]);
response(#imap_resp{data = {lsub,Flags}} = Resp,Acc) ->
	Data = flags_resp(Flags),
	response(Resp#imap_resp{data = []},[32,Data|Acc]);

response(#imap_resp{data = Data} = Resp,Acc) when is_list(Data), Data /= [] ->
	response(Resp#imap_resp{data = []},[32,41,[],40|Acc]);
%% INFO
response(#imap_resp{info = {list,Heirachy,Name}} = Resp,Acc) -> 
	Info = [quote(Heirachy,true),32,quote(Name,true)],
	response(Resp#imap_resp{info = []},[32,Info|Acc]);
response(#imap_resp{info = {lsub,Heirachy,Name}} = Resp,Acc) -> 
	Info = [quote(Heirachy,true),32,quote(Name,true)],
	response(Resp#imap_resp{info = []},[32,Info|Acc]);
response(#imap_resp{info = Info} = Resp,Acc) when is_list(Info), Info /= [] -> 
	response(Resp#imap_resp{info = []},[32,Info|Acc]);
response(Resp,Acc) -> 
	?D({Resp,Acc}),
	{error,unkown_response}.

%%-------------------------------------------------------------------------
%% @spec (String::string()) -> {string(),string()}
%% @doc Finds space to break string when double quotes strings are found
%% @end
%%-------------------------------------------------------------------------
re_split(String) -> re_split(String,"^(\"[^\"]*\")",32,34).

%%-------------------------------------------------------------------------
%% @spec (String::string(),RegExp::string(),Space::integer(),Quote::integer()) -> {string(),string()}
%% @hidden
%% @end
%%-------------------------------------------------------------------------
re_split(String,RegExp,Space,Quote) ->
	?D(String),
	{One,Two} = case string:chr(String, Space) of
		0 -> {String,[]};
		Pos -> 
			case string:chr(String, Quote) of
				0 ->
					case lists:split(Pos,String) of
						{O,T} -> {O,T};
						Other -> Other
					end;
				_ -> 
					case regexp:match(String,RegExp) of
						{match,Start,Length} when Start + Length >= length(String) -> 
							?D({Start,Length}),
							lists:split(Pos,String);
						{match,Start,Length} when Start < Pos -> 
							?D({Start,Length}),
							case lists:prefix([34,34],String) of
								true -> 
									{_O,T} = lists:split(3,String),
									{[],T};
								false -> lists:split(Start + Length,String)
							end;
						nomatch -> 
							case lists:split(Pos,String) of
								{O,T} -> 
									case regexp:match(T,RegExp) of
										{match,_,_} -> {O,imapd_util:clean(T)};
										nomatch -> {O,T}
									end;
								Other -> Other
							end
					end
			end
	end,
	{imapd_util:clean(One),Two}.



%%-------------------------------------------------------------------------
%% @spec (Message::string(),Socket::port()) -> ok | {error,string()}
%% @doc Sends a Message to Socket adds CRLF if needed.
%% @end
%%-------------------------------------------------------------------------
send(Resp,State) when is_record(Resp,imap_resp)  -> send(response(Resp),State);
send(Msg,State)  when is_record(State,imapd_fsm) -> send(Msg,State#imapd_fsm.socket);
send(Message,Socket) ->
%	?D(Message),
	Msg = case string:right(Message,2) of
		?CRLF -> [Message];
		_      -> [Message,?CRLF]
	end,
%	?D(Msg),
	gen_tcp:send(Socket,Msg).

%%-------------------------------------------------------------------------
%% @spec (Sequence::string()) -> list()
%% @doc Converts an IMAP sequence string into a lsit of intgers
%% @end
%%-------------------------------------------------------------------------
seq_to_list("1:*") -> all;
seq_to_list([I|_] = Seq) when is_integer(I) -> seq_to_list(string:tokens(Seq,","));
seq_to_list(Seq) -> seq_to_list(Seq,[]).
%%-------------------------------------------------------------------------
%% @spec (Sequence::string(),list()) -> list()
%% @hidden
%% @end
%%-------------------------------------------------------------------------
seq_to_list([],Acc) -> lists:usort(lists:flatten(lists:reverse(Acc)));
seq_to_list([H|T],Acc) ->
	case catch list_to_integer(H) of
		Int when is_integer(Int) -> seq_to_list(T,[Int|Acc]);
		_ ->
			[S,E] = string:tokens(H,":"),
			Start = list_to_integer(S),
			End = list_to_integer(E),
			seq_to_list(T,[lists:seq(Start,End)|Acc])
	end.


%%-------------------------------------------------------------------------
%% @spec split_at(String::string()) -> {string(),string()}
%% @doc Splits the given string into two strings at the first SPACE (chr(32))
%% @end
%%-------------------------------------------------------------------------
split_at(String) -> split_at(String,32).
%%-------------------------------------------------------------------------
%% @spec split_at(String::string(),Chr::char()) -> {string(),string()}
%% @doc Splits the given string into two strings at the first instace of Chr
%% @end
%%-------------------------------------------------------------------------
split_at(String,Chr) -> 
	case string:chr(String, Chr) of
		0 -> {String,[]};
		Pos -> 
			case lists:split(Pos,String) of
				{One,Two} -> {string:strip(One),Two};
				Other -> Other
			end
	end.

%%-------------------------------------------------------------------------
%% @spec status_flags(string()) -> list()
%% @doc Takes a string os status requests and returns a list of 
%%      status requests
%% @end
%%-------------------------------------------------------------------------
status_flags(String) ->
	Tokens = string:tokens(String," ()"),
	lists:map(fun(S) -> list_to_atom(http_util:to_lower(S)) end,Tokens).

%%-------------------------------------------------------------------------
%% @spec status_info(MailBoxInfo::tuple(),List::list()) -> list()
%% @doc Takes a list of status flags or a status string and returns 
%%      information for each requested flag
%% @end
%%-------------------------------------------------------------------------
status_info(MailBoxInfo,[H|_] = List) when is_integer(H) -> status_info(MailBoxInfo,status_flags(List));
status_info(MailBoxInfo,[H|_] = List) when is_atom(H) -> status_info(MailBoxInfo,List,[]).
%%-------------------------------------------------------------------------
%% @spec status_info(tuple(),list(),list()) -> list()
%% @hidden
%% @end
%%-------------------------------------------------------------------------
status_info(#mailbox{messages = Messages} = MailBoxInfo,[messages|T],Acc) ->
	status_info(MailBoxInfo,T,[{messages, Messages}|Acc]);
status_info(#mailbox{recent = Recent} = MailBoxInfo,[recent|T],Acc) ->
	status_info(MailBoxInfo,T,[{recent, Recent}|Acc]);
status_info(#mailbox{uidnext = UIDNext} = MailBoxInfo,[uidnext|T],Acc) ->
	status_info(MailBoxInfo,T,[{uidnext, UIDNext}|Acc]);
status_info(#mailbox{uidvalidity = UIDValidity} = MailBoxInfo,[uidvalidity|T],Acc) ->
	status_info(MailBoxInfo,T,[{uidvalidity, UIDValidity}|Acc]);
status_info(#mailbox{unseen = UnSeen} = MailBoxInfo,[unseen|T],Acc) ->
	status_info(MailBoxInfo,T,[{unseen, UnSeen}|Acc]);
status_info(_MailBoxInfo,[],Acc) -> lists:reverse(Acc).

%%-------------------------------------------------------------------------
%% @spec status_resp(list()) -> string()
%% @doc Takes a list of status information and returns a response string
%% @end
%%-------------------------------------------------------------------------
status_resp([]) -> "()";
status_resp(List) -> status_resp(List,[]).
%%-------------------------------------------------------------------------
%% @spec status_resp(list(),list()) -> string()
%% @hidden
%% @end
%%-------------------------------------------------------------------------
status_resp([{Type,Info}|T],Acc) ->
	status_resp(T,[32,integer_to_list(Info),32,http_util:to_upper(atom_to_list(Type))|Acc]);
status_resp([],Acc) -> "(" ++ string:strip(lists:flatten(lists:reverse(Acc))) ++ ")".


%%-------------------------------------------------------------------------
%% @spec (String::string()) -> string()
%% @doc Removes Double Quotes and white space from both sides of a string
%% @end
%%-------------------------------------------------------------------------
unquote(String) -> 
	S2 = string:strip(String,both,32),
	string:strip(S2,both,34).