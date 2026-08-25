#!/usr/bin/perl
# Copyright 2026 Digital Envoy, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Tests for query_xml() against a local mock UDP server.
#
# XML UDP framing (as the module implements it):
#   bytes 0-1 : 2-char ASCII packet number, e.g. "01"
#   bytes 2-3 : 2-char ASCII total packet count, e.g. "01"
#   bytes 4.. : XML payload (last byte stripped by substr(..., 4, -1))
#
# Single-packet example: "0101" . $xml . "\0"
#
# Each test gets its own fresh port to avoid cross-test contamination.
use strict;
use warnings;
use Test::More;

use lib 'lib', 'perl';
eval { require NetAcuity_API };
if ($@) {
    plan skip_all => "NetAcuity_API failed to load: $@";
}

eval { require XML::LibXML };
if ($@) {
    plan skip_all => "XML::LibXML not available: $@";
}

my $use_threads = 0;
my $use_fork    = 0;
eval { require threads; $use_threads = 1 };
unless ($use_threads) {
    use Config;
    $use_fork = 1 if $Config{d_fork};
}
unless ($use_threads || $use_fork) {
    plan skip_all => 'threads and fork unavailable — cannot run mock UDP server';
}

eval { require IO::Socket::INET };
if ($@) {
    plan skip_all => "IO::Socket::INET not available: $@";
}

# -----------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------
sub _find_free_udp_port {
    for my $try (19500..19699) {
        my $s = IO::Socket::INET->new(
            LocalPort => $try, LocalAddr => '127.0.0.1',
            Proto => 'udp', ReuseAddr => 1,
        );
        if ($s) { $s->close; return $try }
    }
    return undef;
}

# Build single-packet XML response per the module's framing protocol.
sub _build_xml_packet { "0101" . $_[0] . "\0" }

# -----------------------------------------------------------------------
# _run_with_server(packet, code_ref)
# Fresh port per invocation; always joins server before returning.
# -----------------------------------------------------------------------
sub _run_with_server {
    my ($response_packet, $test_code) = @_;

    my $port = _find_free_udp_port();
    BAIL_OUT('Could not find a free UDP port for mock server') unless defined $port;

    if ($use_threads) {
        my $t = threads->create(sub {
            my $sock = IO::Socket::INET->new(
                LocalPort => $port, LocalAddr => '127.0.0.1',
                Proto => 'udp', ReuseAddr => 1,
            ) or return;
            my ($buf, $from);
            $sock->recv($buf, 4096);
            $from = $sock->peername;
            $sock->send($response_packet, 0, $from);
            $sock->close;
        });
        select(undef, undef, undef, 0.15);
        $test_code->($port);
        $t->join;
    } else {
        require POSIX;
        my $pid = fork() // BAIL_OUT('fork() failed');
        if ($pid == 0) {
            my $sock = IO::Socket::INET->new(
                LocalPort => $port, LocalAddr => '127.0.0.1',
                Proto => 'udp', ReuseAddr => 1,
            ) or POSIX::_exit(1);
            my ($buf, $from);
            $sock->recv($buf, 4096);
            $from = $sock->peername;
            $sock->send($response_packet, 0, $from);
            $sock->close;
            POSIX::_exit(0);
        }
        select(undef, undef, undef, 0.15);
        $test_code->($port);
        waitpid($pid, 0);
    }
}

plan tests => 32;

# -----------------------------------------------------------------------
# 1. Basic successful XML query — single packet (7 tests)
# -----------------------------------------------------------------------
_run_with_server(
    _build_xml_packet('<response trans-id="1" ip="203.0.113.1" country="usa" region="ca" city="mountain view" />'),
    sub {
        my ($port) = @_;
        my $na = NetAcuity_API->new(server_addr => '127.0.0.1', server_port => $port,
                                     api_id => 1, timeout => 3);
        my $resp = $na->query_xml('203.0.113.1', '3', '1');
        ok(defined $resp,                     'XML query: response hash ref defined');
        is($resp->{country}, 'usa',           'XML query: country in response');
        is($resp->{region},  'ca',            'XML query: region in response');
        is($resp->{city},    'mountain view', 'XML query: city in response');
        like($na->xml_response(), qr/country="usa"/, 'XML query: xml_response() holds the raw XML');
        is($na->raw_response(), $na->xml_response(), 'XML query: raw_response() matches the raw XML string');
        ok(!exists $resp->{error}, 'XML query: no error key on success');
    }
);

# -----------------------------------------------------------------------
# 2. xml_query request built correctly (5 tests)
# -----------------------------------------------------------------------
_run_with_server(
    _build_xml_packet('<response trans-id="tx1" ip="203.0.113.1" country="deu" />'),
    sub {
        my ($port) = @_;
        my $na = NetAcuity_API->new(server_addr => '127.0.0.1', server_port => $port,
                                     api_id => 5, timeout => 3);
        $na->query_xml('203.0.113.1', '3,7', 'tx1');
        my $q = $na->xml_query();
        ok(defined $q,                 'xml_query() is set after query_xml');
        like($q, qr/ip='203\.0\.113\.1'/, 'xml_query: IP embedded in request');
        like($q, qr/api-id='5'/,       'xml_query: api_id embedded in request');
        like($q, qr/trans-id='tx1'/,   'xml_query: trans-id embedded in request');
        like($q, qr/<query db='3'\//,  'xml_query: feature 3 present');
    }
);

# -----------------------------------------------------------------------
# 3. Multi-feature query (2 tests)
# -----------------------------------------------------------------------
_run_with_server(
    _build_xml_packet('<response trans-id="2" ip="203.0.113.1" country="fra" timezone="europe/paris" />'),
    sub {
        my ($port) = @_;
        my $na = NetAcuity_API->new(server_addr => '127.0.0.1', server_port => $port,
                                     api_id => 1, timeout => 3);
        my $resp = $na->query_xml('203.0.113.1', '3,7,10,26', '2');
        is($resp->{country}, 'fra', 'multi-feature: country in response');
        my $q = $na->xml_query();
        like($q, qr/<query db='26'\//, 'multi-feature: feature 26 in query');
    }
);

# -----------------------------------------------------------------------
# 4. query_xml already returns named fields directly -- no separate
# xml_parse() call needed (4 tests)
# -----------------------------------------------------------------------
_run_with_server(
    _build_xml_packet('<response trans-id="99" ip="203.0.113.1" country="jpn" city="tokyo" latitude="35.6762" />'),
    sub {
        my ($port) = @_;
        my $na = NetAcuity_API->new(server_addr => '127.0.0.1', server_port => $port,
                                     api_id => 1, timeout => 3);
        my $data = $na->query_xml('203.0.113.1', '3', '99');
        is($data->{country},    'jpn',     'one-call: country parsed');
        is($data->{city},       'tokyo',   'one-call: city parsed');
        is($data->{latitude},   '35.6762', 'one-call: latitude parsed');
        is($data->{'trans-id'}, '99',      'one-call: trans-id parsed');
    }
);

# -----------------------------------------------------------------------
# 5. Timeout — RFC 5737 TEST-NET-1 (192.0.2.0/24), guaranteed no response
# (2 tests)
# -----------------------------------------------------------------------
{
    my $na = NetAcuity_API->new(
        server_addr => '192.0.2.1', server_port => 5400,
        api_id => 1, timeout => 0.3,
    );
    my $resp = $na->query_xml('203.0.113.1', '3', '1');
    ok(defined $resp->{error}, 'XML timeout: response contains an error key');
    ok(!defined $na->raw_response(), 'XML timeout: raw_response() not set (no genuine bytes received)');
}

# -----------------------------------------------------------------------
# 6. Server-side error response — parsed correctly (3 tests)
# A DB-level error in the payload is still a successful protocol exchange
# (the server responded, in-sync, to our request), so raw_response() is set.
# -----------------------------------------------------------------------
_run_with_server(
    _build_xml_packet('<response trans-id="1" ip="203.0.113.1" error="DB Not Loaded" />'),
    sub {
        my ($port) = @_;
        my $na = NetAcuity_API->new(server_addr => '127.0.0.1', server_port => $port,
                                     api_id => 1, timeout => 3);
        my $data = $na->query_xml('203.0.113.1', '3', '1');
        is($data->{error}, 'DB Not Loaded', 'XML error response: error field parsed');
        ok(defined $data->{error}, 'XML error response: error key present in hash');
        like($na->raw_response(), qr/error="DB Not Loaded"/,
            'XML error response: raw_response() still set (protocol-level success)');
    }
);

# -----------------------------------------------------------------------
# 7. Response IP echo mismatch is rejected (3 tests)
# -----------------------------------------------------------------------
_run_with_server(
    _build_xml_packet('<response trans-id="1" ip="203.0.113.99" country="usa" />'),
    sub {
        my ($port) = @_;
        my $na = NetAcuity_API->new(server_addr => '127.0.0.1', server_port => $port,
                                     api_id => 1, timeout => 3);
        my $resp = $na->query_xml('203.0.113.1', '3', '1');
        like($resp->{error}, qr/mismatch/, 'XML response IP mismatch: error field mentions mismatch');
        ok(defined $resp, 'XML response IP mismatch: response still defined');
        ok(defined $na->raw_response(),
            'XML response IP mismatch: raw_response() IS set (genuine bytes were received, just rejected)');
    }
);

# -----------------------------------------------------------------------
# 8. Differently-formatted-but-equal IPv6 response IP is accepted (2 tests)
# The server may echo back a compressed form of the same IPv6 address that
# was queried in expanded form -- this must not be treated as a mismatch.
# -----------------------------------------------------------------------
_run_with_server(
    _build_xml_packet('<response trans-id="1" ip="2001:db8::1" country="usa" />'),
    sub {
        my ($port) = @_;
        my $na = NetAcuity_API->new(server_addr => '127.0.0.1', server_port => $port,
                                     api_id => 1, timeout => 3);
        my $resp = $na->query_xml('2001:0db8:0000:0000:0000:0000:0000:0001', '3', '1');
        is($resp->{error}, undef, 'differently-formatted-equal IPv6: no error set');
        is($resp->{country}, 'usa', 'differently-formatted-equal IPv6: country parsed');
    }
);

# -----------------------------------------------------------------------
# 9. Response missing the trans-id/ip attributes entirely is rejected, not
# silently accepted -- a missing field is itself a failure (2 tests)
# -----------------------------------------------------------------------
_run_with_server(
    _build_xml_packet('<response country="usa" />'),
    sub {
        my ($port) = @_;
        my $na = NetAcuity_API->new(server_addr => '127.0.0.1', server_port => $port,
                                     api_id => 1, timeout => 3);
        my $resp = $na->query_xml('203.0.113.1', '3', '1');
        like($resp->{error}, qr/mismatch/i, 'missing trans-id/ip attributes: rejected as a mismatch');
        ok(defined $na->raw_response(), 'missing trans-id/ip attributes: raw_response() still set');
    }
);

# -----------------------------------------------------------------------
# 10. xml_parse() remains available for re-parsing a stored xml_response()
# (2 tests)
# -----------------------------------------------------------------------
_run_with_server(
    _build_xml_packet('<response trans-id="7" ip="203.0.113.1" country="can" />'),
    sub {
        my ($port) = @_;
        my $na = NetAcuity_API->new(server_addr => '127.0.0.1', server_port => $port,
                                     api_id => 1, timeout => 3);
        $na->query_xml('203.0.113.1', '3', '7');
        my %data;
        $na->xml_parse(\%data);
        is($data{country}, 'can', 'xml_parse() re-parse: country');
        is_deeply([sort $na->xml_field_order()], [sort qw(trans-id ip country)],
            'xml_field_order() reflects the fields from the most recent parse');
    }
);
