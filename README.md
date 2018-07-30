no-dbus
=======

Originally by: Ivan Shmakov <ivan@siamics.net>

Posted to: alt.sources

On: Sat, 28 Jul 2018 12:07:38 +0000

Message-ID: <87bmarbm2d.fsf@violet.siamics.net>

Archive-name: no-dbus-perl-2018-is

Copyright-Notice: Both this README and the code are available under
 CC0 Public Domain Dedication 1.0;
 see http://creativecommons.org/publicdomain/zero/1.0/.

This copy put on github as

https://github.com/Eli-the-Bearded/no-dbus

because I think github is a better place to find and share source code in 
the 2010s than an alt newsgroup. -- EtB

no-dbus.perl 0.1: a D-Bus non-implementation
--------------------------------------------

Note from the original author:

>	[Followup-To: set to news:alt.sources.d, as per the
>	news:alt.sources charter, and also to news:comp.os.linux.misc.
>	I will also monitor news:comp.lang.perl.misc, in case someone
>	would wish to comment on the coding style or some such.]


##  Synopsis

```
# rm -- /run/dbus/system_bus_socket || mkdir -v -- /run/dbus 
# chown -- nobody /run/dbus 
# setsid -- su nobody -c perl\ no-dbus.perl & 
```

##  Summary

When X.Org X server (at least as of version 1.19.2) is built
with D-Bus support, such as the case for Debian 9 "Stretch,"
it logs every failure to connect to the D-Bus server, and also
reattempts such connections every 10 seconds or so, resulting
in the log growing by about 191 octets every 10 seconds
(or 1.57 MiB/day) until and unless a connection is successfully
established.  (Cf. [1, 2].)

Seemingly, the lack of active D-Bus connection also reduces the
X server performance.

Neither the documentation nor the source (at least for 1.19.2)
seem to hint at a possibility of disabling D-Bus support by some
run-time option.  From there, available solutions are as follows.

* Run a system D-Bus server on the machine.  Cons.: one needs to
  learn the why and how X server (and possibly other installed
  software) uses D-Bus and take it into account when
  troubleshooting; also, as any software, said server may have
  (and probably has) unidentified bugs, including those that can
  be exploited by a malicious party.

* Redirect the log to `/dev/null` (e. g., `-logfile /dev/null`.)
  Cons.: this also loses the valuable log messages; the X server
  performance may still be affected.

* Do nothing.  Perhaps restart X server once in a while, so the
  log gets rotated (and older copies lost.)  Cons.: inconvenient;
  performance may still be affected.

* Run a simplistic server, which will answer as necessary
  to the handshake performed by X server, but will otherwise
  do nothing.  Cons.: takes time and effort to get it right.

The present `no-dbus.perl` server implements the last of the above.

[1] xorg flooded by dbus messages // Debian Bug report logs
    http://bugs.debian.org/868453
[2] /var/log/Xorg.0.log gets flooded with (EE) dbus-...
    http://bugs.launchpad.net/ubuntu/+source/xorg-server/+bug/1562610


##  Bugs

Not tested with other software which may demand a running D-Bus
daemon instance.

The "Hello" handshake handling is a hack.  First of all, it
searches for magic strings in the request (in place of proper
decoding.)  Then, I haven't figured out how to produce a correct
response (see the commented-out my $reply section in the code)
and just put in the code the one which a "real" D-Bus server emits.

Native octet order is assumed.

No --no-debug option.

A copy is not yet available from under http://am-1.org/~ivan/src/.


##  Meta

This README documents no-dbus.perl 0.1 (2017.U44uEkvB, authored 2017-12-16 17:53:34Z.)

