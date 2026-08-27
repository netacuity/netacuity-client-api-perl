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

use strict;
use warnings;
use Test::More;
use Socket qw(AF_INET AF_INET6 SOCK_DGRAM);

use lib 'lib', 'perl';
eval { require NetAcuity_API };
if ($@) {
    plan skip_all => "NetAcuity_API failed to load: $@";
}

plan tests => 39;

my $na = NetAcuity_API->new(server_addr => '192.0.2.1');

# -----------------------------------------------------------------------
# server_addr: getter and setter
# -----------------------------------------------------------------------
is($na->server_addr(), '192.0.2.1', 'server_addr() getter returns initial value');

# Suppress the debug print that is currently in server_addr()
{
    local *STDOUT;
    open(STDOUT, '>', \my $discard);
    $na->server_addr('192.0.2.5');
}
is($na->server_addr(), '192.0.2.5', 'server_addr() setter updates value');

# setter updates addr_family for IPv4
{
    local *STDOUT;
    open(STDOUT, '>', \my $discard);
    $na->server_addr('203.0.113.1');
}
is($na->{'addr_family'}, AF_INET, 'server_addr() setter detects IPv4 (no colon)');

# setter updates addr_family for IPv6
{
    local *STDOUT;
    open(STDOUT, '>', \my $discard);
    $na->server_addr('2001:db8::1');
}
is($na->{'addr_family'}, AF_INET6, 'server_addr() setter detects IPv6 (has colon)');

# Reset back to IPv4
{
    local *STDOUT;
    open(STDOUT, '>', \my $discard);
    $na->server_addr('192.0.2.1');
}

# -----------------------------------------------------------------------
# server_port: getter and setter
# -----------------------------------------------------------------------
is($na->server_port(), 5400, 'server_port() getter returns default');
$na->server_port(9999);
is($na->server_port(), 9999, 'server_port() setter updates value');
$na->server_port(5400);  # reset

# -----------------------------------------------------------------------
# api_id: getter and setter
# -----------------------------------------------------------------------
is($na->api_id(), 0, 'api_id() getter returns default');
$na->api_id(75);
is($na->api_id(), 75, 'api_id() setter stores valid value');

# Out-of-range values are stored as-is; validation happens at query time
$na->api_id(-5);
is($na->api_id(), -5, 'api_id() setter stores negative values as-is');

$na->api_id(200);
is($na->api_id(), 200, 'api_id() setter stores >127 values as-is');

$na->api_id(0);
is($na->api_id(), 0, 'api_id() setter accepts boundary value 0');

$na->api_id(127);
is($na->api_id(), 127, 'api_id() setter accepts boundary value 127');

$na->api_id(64);
is($na->api_id(), 64, 'api_id() setter accepts mid-range value');

# Called with no args acts as getter (does not change value)
my $current = $na->api_id();
$na->api_id();
is($na->api_id(), $current, 'api_id() with no args does not change value');

$na->api_id(0);  # reset

# -----------------------------------------------------------------------
# timeout: getter and setter
# -----------------------------------------------------------------------
is($na->timeout(), 2, 'timeout() getter returns default');
$na->timeout(10);
is($na->timeout(), 10, 'timeout() setter updates value');
$na->timeout(0);
is($na->timeout(), 0, 'timeout() setter accepts 0');
$na->timeout(2);  # reset

# -----------------------------------------------------------------------
# timeout_seconds: preferred accessor name, aliasing the same field as
# timeout()
# -----------------------------------------------------------------------
is($na->timeout_seconds(), 2, 'timeout_seconds() getter returns default');
$na->timeout_seconds(10);
is($na->timeout(), 10, 'timeout_seconds() setter is reflected by timeout()');
$na->timeout(4);
is($na->timeout_seconds(), 4, 'timeout() setter is reflected by timeout_seconds()');
$na->timeout(2);  # reset

# -----------------------------------------------------------------------
# error_msg: getter and setter
# -----------------------------------------------------------------------
is($na->error_msg(), '', 'error_msg() getter returns empty string initially');
$na->error_msg('Something went wrong');
is($na->error_msg(), 'Something went wrong', 'error_msg() setter stores message');
$na->error_msg('');
is($na->error_msg(), '', 'error_msg() setter clears message');

# -----------------------------------------------------------------------
# stream_type: getter and setter
# -----------------------------------------------------------------------
is($na->stream_type(), SOCK_DGRAM, 'stream_type() getter returns SOCK_DGRAM default');
$na->stream_type(99);
is($na->stream_type(), 99, 'stream_type() setter stores arbitrary value');
$na->stream_type(SOCK_DGRAM);  # reset

# -----------------------------------------------------------------------
# type: getter and setter
# -----------------------------------------------------------------------
is($na->type(), 'udp', 'type() getter returns default udp');

# setting to udp explicitly still works
$na->type('udp');
is($na->type(), 'udp', 'type() setter accepts udp');
is($na->stream_type(), SOCK_DGRAM, 'type(udp) sets stream_type to SOCK_DGRAM');
is($na->server_port(), 5400, 'type(udp) resets port to 5400');

# setting non-udp value: the code warns but still sets SOCK_DGRAM/5400
{
    local $SIG{__WARN__} = sub {};  # suppress the warning
    $na->type('tcp');
}
is($na->stream_type(), SOCK_DGRAM, 'type(tcp) still sets SOCK_DGRAM (only UDP supported)');
is($na->server_port(), 5400, 'type(tcp) still sets port 5400 (only UDP supported)');

# type() with no args is a getter
my $t = $na->type();
$na->type();
is($na->type(), $t, 'type() with no arg does not alter value');

# -----------------------------------------------------------------------
# xml_query: getter and setter
# -----------------------------------------------------------------------
is($na->xml_query(), undef, 'xml_query() returns undef initially');
$na->xml_query('<request/>');
is($na->xml_query(), '<request/>', 'xml_query() setter stores string');
$na->xml_query(undef);
is($na->xml_query(), '<request/>', 'xml_query() with undef does not clear value');

# -----------------------------------------------------------------------
# xml_response: getter and setter
# -----------------------------------------------------------------------
is($na->xml_response(), undef, 'xml_response() returns undef initially');
$na->xml_response('<response/>');
is($na->xml_response(), '<response/>', 'xml_response() setter stores string');

# -----------------------------------------------------------------------
# server_info: read-only alias for server_addr
# -----------------------------------------------------------------------
{
    local *STDOUT;
    open(STDOUT, '>', \my $discard);
    $na->server_addr('198.51.100.40');
}
is($na->server_info(), '198.51.100.40', 'server_info() reflects latest server_addr');

# -----------------------------------------------------------------------
# Chained accessor calls (getter returns scalar, not object)
# -----------------------------------------------------------------------
my $port_val = $na->server_port(8080);
is($port_val, 8080, 'accessor setter returns the stored value');
