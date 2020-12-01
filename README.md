##gtcp
=====

GTCP is a simple skeleton for TCP asynchronous socket server using Erlang's new ["socket" module](https://erlang.org/doc/man/socket.html).

I use gtcp for various experiments with handling connection-oriented applications like card switches (ISO8583 protocol) or HSM (like Thales9000).

###Overview
--------
TCP server starts at 127.0.0.1 and port defined in gtcp_acpt (param. PORT).

Incomming connections are handled purely asynchronously by acceptor module (gtcp_acpt, as gen_server). Each accepted connection is handled by new process (as gen_server) with dynamic supervision pattern.

Acceptor can work in one of two pre-determined modes:
- with asynchronous connection handlers (gtcp_async_srv)
- with full-duplex connection handler (gtcp_vctr_srv, gtcp_vctr_sender, gtcp_vctr_receiver)
The mode is defined in gtcp_acpt (param. SERVER_CREATION_FUN).  

Messages over connections are expected to have length prefix. The size of the length prefix is defined in gtcp_async_srv/gtcp_vctr_receiver in par.PFX_LEN.

Socket read is handled by Receiver (gtcp_async_server or gtcp_vctr_receiver, depending on mode). Receiver function reads incomming socket data in chunks (par. BLOCK_SIZE). Receive is asynchronous. On each internal "select" message from socket module, Receiver parses block of data decomposing full messages, until buffer is exhausted. This initiates new read request on the socket.

For each decomposed message, Receiver spawns "worker" process (non-OTP) that is expected to process the message. On completition, worker sends response message via Sender.

Sender implements socket send operation and is provided either in gtcp_async_srv or gtcp_vctr_sender, depending on mode. In this version of gtcp, send is synchronous (with short timeout). This can easily be changed to asynchronous.

In full-duplex mode, socket read is handled concurrently with send by separate processes (gtcp_vctr_receiver and gtcp_vctr_sender).

###Testing
-------
'''
{ok,S}=gtcp_acpt:connect(). -> client connect with automatic length prefix handling.

{ok,S}=gtcp_acpt:connect(raw). -> client connect with no length prefix, subsequent messages have to manually handle length prefix. This is useful for debugging chunk parsing on the server side.

Assuming client connection with automatic length prefix handling:
gtcp_acpt:send(S,<<"example message">>).

Assuming connection with manual length prefix handling:
gtcp_acpt:send(S,<<0,15,"example message">>).

Responses to command-line client can be traced by flush().

There are additional functions for checking dynamic supervision of handlers:
gtcp_acpt:which_children(). -> dynamic children
gtcp_acpt:which_children(top). -> top-level supervisor

###Build
-----

    $ rebar3 compile
    or
    $ rebar3 shell

Enjoy!
