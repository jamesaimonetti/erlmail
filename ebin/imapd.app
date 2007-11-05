{application, imapd,
 [
  {description, "Erlang IMAP Server"},
  {vsn, "0.0.6"},
  {id, "imapd_listener"},
  {modules,      [imapd_listener, imapd_fsm]},
  {registered,   [imapd_sup, imapd_listner]},
  {applications, [kernel, stdlib]},
  {mod, {imapd_app, []}},
  {env, [{listen_port, 143}]}
 ]
}.