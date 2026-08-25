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

plan tests => 32;

# -----------------------------------------------------------------------
# Basic object construction
# -----------------------------------------------------------------------
my $na = NetAcuity_API->new(server_addr => '192.0.2.1');
ok(defined $na, 'new() returns a defined value');
isa_ok($na, 'NetAcuity_API', 'new() returns a NetAcuity_API object');

# -----------------------------------------------------------------------
# Default values when only server_addr is provided
# -----------------------------------------------------------------------
is($na->{'server_addr'},  '192.0.2.1', 'server_addr stored correctly');
is($na->{'server_port'},  5400,         'default server_port is 5400');
is($na->{'api_id'},       0,            'default api_id is 0');
is($na->{'timeout_seconds'}, 2,         'default timeout_seconds is 2');
is($na->{'type'},         'udp',        'default type is udp');
is($na->{'stream_type'},  SOCK_DGRAM,   'default stream_type is SOCK_DGRAM');
is($na->{'addr_family'},  AF_INET,      'IPv4 server sets addr_family to AF_INET');
is($na->{'error_msg'},    '',           'error_msg starts empty');

# -----------------------------------------------------------------------
# Explicit parameters are honored
# -----------------------------------------------------------------------
my $na2 = NetAcuity_API->new(
    server_addr => '192.0.2.1',
    server_port => 9000,
    api_id      => 42,
    timeout     => 5,
    type        => 'udp',
);
is($na2->{'server_port'}, 9000, 'explicit server_port stored');
is($na2->{'api_id'},      42,   'explicit api_id stored');
is($na2->{'timeout_seconds'}, 5, 'explicit timeout (legacy key) stored under timeout_seconds');

my $na2b = NetAcuity_API->new(server_addr => '192.0.2.1', timeout_seconds => 7);
is($na2b->{'timeout_seconds'}, 7, 'explicit timeout_seconds stored');

# -----------------------------------------------------------------------
# api_id values are stored as-is in the constructor; out-of-range values
# are rejected at query time instead (see query_xml tests).
# -----------------------------------------------------------------------
my $na_low = NetAcuity_API->new(server_addr => '192.0.2.1', api_id => -1);
is($na_low->{'api_id'}, -1, 'api_id -1 stored as-is in constructor');

my $na_high = NetAcuity_API->new(server_addr => '192.0.2.1', api_id => 128);
is($na_high->{'api_id'}, 128, 'api_id 128 stored as-is in constructor');

my $na_max = NetAcuity_API->new(server_addr => '192.0.2.1', api_id => 127);
is($na_max->{'api_id'}, 127, 'api_id 127 (max valid) stored as-is');

my $na_min = NetAcuity_API->new(server_addr => '192.0.2.1', api_id => 0);
is($na_min->{'api_id'}, 0, 'api_id 0 (min valid) stored as-is');

my $na_mid = NetAcuity_API->new(server_addr => '192.0.2.1', api_id => 64);
is($na_mid->{'api_id'}, 64, 'api_id 64 (mid-range) stored as-is');

my $na_empty_id = NetAcuity_API->new(server_addr => '192.0.2.1', api_id => '');
is($na_empty_id->{'api_id'}, 0, 'empty string api_id defaults to 0 in constructor');

# -----------------------------------------------------------------------
# Port defaults when empty string given
# -----------------------------------------------------------------------
my $na_empty_port = NetAcuity_API->new(server_addr => '192.0.2.1', server_port => '');
is($na_empty_port->{'server_port'}, 5400, 'empty server_port defaults to 5400');

# -----------------------------------------------------------------------
# Timeout defaults when empty string given
# -----------------------------------------------------------------------
my $na_empty_timeout = NetAcuity_API->new(server_addr => '192.0.2.1', timeout => '');
is($na_empty_timeout->{'timeout_seconds'}, 2, 'empty timeout defaults to 2');

# -----------------------------------------------------------------------
# Non-UDP type silently becomes UDP
# -----------------------------------------------------------------------
my $na_tcp = NetAcuity_API->new(server_addr => '192.0.2.1', type => 'tcp');
is($na_tcp->{'type'}, 'udp', 'non-udp type silently coerced to udp');
is($na_tcp->{'stream_type'}, SOCK_DGRAM, 'non-udp type still gets SOCK_DGRAM');

# -----------------------------------------------------------------------
# IPv6 server address detection
# -----------------------------------------------------------------------
my $na_v6 = NetAcuity_API->new(server_addr => '2001:db8::1');
is($na_v6->{'addr_family'}, AF_INET6, 'IPv6 server address sets addr_family to AF_INET6');

my $na_v6_full = NetAcuity_API->new(server_addr => '2001:db8::1');
is($na_v6_full->{'addr_family'}, AF_INET6, 'Full IPv6 address detected correctly');

# -----------------------------------------------------------------------
# IPv4 address with no colons stays AF_INET
# -----------------------------------------------------------------------
my $na_v4 = NetAcuity_API->new(server_addr => '203.0.113.1');
is($na_v4->{'addr_family'}, AF_INET, 'Standard IPv4 address stays AF_INET');

# -----------------------------------------------------------------------
# server_info() returns the server address
# -----------------------------------------------------------------------
is($na->server_info(), '192.0.2.1', 'server_info() returns server_addr');

# -----------------------------------------------------------------------
# Multiple independent objects don't share state
# -----------------------------------------------------------------------
my $na_a = NetAcuity_API->new(server_addr => '192.0.2.10', api_id => 10);
my $na_b = NetAcuity_API->new(server_addr => '198.51.100.1', api_id => 20);
is($na_a->{'server_addr'}, '192.0.2.10', 'object a has its own server_addr');
is($na_b->{'server_addr'}, '198.51.100.1', 'object b has its own server_addr');
is($na_a->{'api_id'}, 10, 'object a has its own api_id');
is($na_b->{'api_id'}, 20, 'object b has its own api_id');
