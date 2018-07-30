#!/usr/bin/perl
### no-dbus.perl  -*- Perl -*-
## No bus is a good bus.  (Would you like to take a tram instead?)

### Ivan Shmakov, 2017

## To the extent possible under law, the author(s) have dedicated
## all copyright and related and neighboring rights to this software
## to the public domain worldwide.  This software is distributed
## without any warranty.

## You should have received a copy of the CC0 Public Domain Dedication
## along with this software.  If not, see
## <http://creativecommons.org/publicdomain/zero/1.0/>.

### History:

## 0.1  2017-12-16
##      Initial revision.

### Code:

use common::sense;
use English qw (-no_match_vars);

require Data::Dump;
# require Getopt::Long;
# require IO::File;
require IO::Handle;
require IO::Select;
require IO::Socket;
require Socket;

## main

die ("Usage: no-dbus [SOCKET-FILE] \n")
    unless (0 <= @ARGV && @ARGV <= 1);

our $debug_p
    = 1;

our $sock_file
    = ($ARGV[0] // "/run/dbus/system_bus_socket");

$SIG{"CHLD"}
    = "IGNORE";
my $listen
    = IO::Socket::UNIX->new  ("Type"    =>  Socket::SOCK_STREAM (),
                              "Local"   =>  $sock_file,
                              "Listen"  =>  1)
    or die ($sock_file, ": Cannot create a listening socket: ", $!);

my $select
    = IO::Select->new ($listen);

while (my @ready = $select->can_read ()) {
  FILEHANDLE:
    foreach my $fh (@ready) {
        if ($fh eq $listen) {
            my $client
                = $fh->accept ()
                or next;
            warn ("D: ", $client->fileno (), ": new connection\n")
                if ($debug_p);
            # $client->binmode ();
            $select->add ($client);
            next;
        }

        my $s;
        my $r
            = $fh->recv ($s, 65536, 0);

        unless (defined ($r) && $s ne "") {
            warn ("W: recv: ", $!, "; closing connection\n")
                unless (defined ($r));
            warn ("D: ", $fh->fileno (), ": remote disconnected\n")
                if ($debug_p && defined ($r));
            $select->remove ($fh);
            $fh->close ();
            next;
        }

        ## Authentication protocol
        my ($prev_pos, $tail)
            = (-1);
        pos ($s)
            = 0;
        while (! exists (${*${fh}}{"bus-auth-p"})
               && defined (pos ($s))) {
            die ("pos not advanced (was: ", $prev_pos, ", now: ", pos ($s), ")\n")
                unless (pos ($s) > $prev_pos);
            $prev_pos
                = pos ($s);
            my ($reject_p, $auth_ok_p, $nego_p, $begin_p, $other)
                =  ($s =~ m {
                        \G \0?
                        (?: (AUTH (\s+ .* \S)? | CANCEL)
                          | (NEGOTIATE_UNIX_FD)
                          | (BEGIN)
                          | (.* \S))
                        \s* \n
                    }xgp);
            # warn ("D: Checking: ", scalar (Data::Dump::dump ($s, $prev_pos, "" . pos ($s))), "\n") if ($debug_p);

            ## FIXME: we assume that the socket is always ready for send
            if ($auth_ok_p) {
                $fh->send ("OK 00000000000000000000000000000000\r\n");
                next;
            } elsif ($reject_p) {
                $fh->send ("REJECTED\r\n");
                next;
            } elsif ($nego_p) {
                ## We do not negotiate with FDs.
                $fh->send ("ERROR\r\n");
                next;
            } elsif ($begin_p) {
                ${*${fh}}{("bus-auth-p")}
                    = ();
                $tail
                    = ${^POSTMATCH};
                next;
            }

            warn ("W: Command not understood: ",
                  scalar (Data::Dump::dump ($other)),
                  "; closing connection\n");
            $select->remove ($fh);
            $fh->close ();
            next
                FILEHANDLE;
        }

        ## Message protocol
        next
            unless (exists (${*${fh}}{"bus-auth-p"}));
        $tail
            //= $s;
        warn ("D: Got: ", scalar (Data::Dump::dump ($tail, $s)), "\n") if ($debug_p);
        while ($tail ne "") {
            ## FIXME: assuming native octet order
            ## order, type, flags, major,  body-len, serial,  head-len
            my @l
                = unpack ("accc LL L", $tail);
            unless ($l[0] eq "l" || $l[0] eq "B") {
                warn ("W: Octet order not understood: ",
                      scalar (Data::Dump::dump ($tail)),
                      "; closing connection\n");
                $select->remove ($fh);
                $fh->close ();
                next
                    FILEHANDLE;
            }
            my ($headers, $body)
                = (substr ($tail, 16, $l[6]),
                   substr ($tail, 16 + ((3 + $l[6]) & ~3), $l[4]));
            $tail
                = substr ($tail,   (16 + ((3 + $l[6]) & ~3)
                                    + ((3 + $l[4]) & ~3)));
            warn ("D: Got: ", scalar (Data::Dump::dump (\@l, $headers, $body, $tail)), "\n") if ($debug_p);
            # warn ("D: Reply? ", scalar (Data::Dump::dump ($headers =~ m { /org/freedesktop/DBus }x, $headers =~ m { org\.freedesktop\.DBus }x, $headers =~ m { Hello }x)), "\n") if ($debug_p);
            if ($l[1] eq 1
                && $headers =~ m { /org/freedesktop/DBus }x
                && $headers =~ m { org\.freedesktop\.DBus }x
                && $headers =~ m { Hello }x) {
                my $reply
                    =  ("l\2\1\1\t\0\0\0\1\0\0\0=\0\0\0"
                        . "\6\1s\0\4\0\0\0:1.0\0\0\0\0"
                        . "\5\1u\0\1\0\0\0"
                        . "\10\1g\0\1s\0\0"
                        . "\7\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0"
                        . "\4\0\0\0:1.0\0");
q {
                my ($header, $body)
                    = (("\5\1u\0" . pack ("L", $l[5])
                        . "\6\1s\0\7\0\0\0:unique\0"
                        . "\7\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0"
                        . "\10\1g\1s\0\0\0"),
                       "\7\0\0\0:unique\0");
                my $reply
                    =  ("l\2\0\1"
                        . pack ("LLL", length ($body), 42,
                                (length ($header)))
                        . $header . $body);
};
                warn ("D: Reply: ", scalar (Data::Dump::dump ($reply)), "\n") if ($debug_p);
                $fh->send ($reply);
            }
        }
    }
}

### no-dbus.perl ends here
__END__
