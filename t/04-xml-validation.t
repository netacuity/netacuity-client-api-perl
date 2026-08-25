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

# Tests for query_xml() input validation —
# all paths that return before touching the network.
use strict;
use warnings;
use Test::More;

use lib 'lib', 'perl';
eval { require NetAcuity_API };
if ($@) {
    plan skip_all => "NetAcuity_API failed to load: $@";
}

plan tests => 44;

sub make_na {
    return NetAcuity_API->new(server_addr => '192.0.2.1', api_id => 1, timeout => 0);
}

# -----------------------------------------------------------------------
# Undefined query_ip: returns an error hash, no network call
# -----------------------------------------------------------------------
{
    my $na = make_na();
    my $resp = $na->query_xml(undef, '3', '42');
    ok(defined $resp, 'undef query_ip returns a defined hash ref');
    ok(defined $resp->{error}, 'undef query_ip response contains an error key');
    like($resp->{error}, qr/IP Address not specified/i, 'undef query_ip: correct error message');
    is($resp->{'trans-id'}, '42', 'undef query_ip: trans-id echoed in response');
    # xml_response accessor should hold the matching raw XML
    like($na->xml_response(), qr/trans-id="42"/, 'xml_response() matches the parsed hash');
}

# -----------------------------------------------------------------------
# Missing transaction_id is rejected (no static default — a static default would
# make the response's transaction-id echo check trivially satisfiable)
# -----------------------------------------------------------------------
{
    my $na = make_na();
    my $resp = $na->query_xml(undef, '3');
    ok(defined $resp->{error}, 'missing transaction_id returns an error hash');
    like($resp->{error}, qr/Transaction ID must be specified/i, 'missing transaction_id: correct error message');
}

# -----------------------------------------------------------------------
# Empty server_addr: returns an error hash
# -----------------------------------------------------------------------
{
    my $na = NetAcuity_API->new(server_addr => '');
    my $resp = $na->query_xml('203.0.113.1', '3', '99');
    ok(defined $resp, 'empty server_addr returns a defined hash ref');
    ok(defined $resp->{error}, 'empty server_addr response contains an error key');
    like($resp->{error}, qr/NetAcuity Server address not set/i, 'empty server_addr: correct error message');
    is($resp->{'trans-id'}, '99', 'empty server_addr: trans-id echoed');
    is($resp->{ip}, '203.0.113.1', 'empty server_addr: query IP echoed');
}

# -----------------------------------------------------------------------
# Invalid feature codes in the comma-separated list
# These are validated after the socket is created, but before sending —
# the check happens once the socket is open. Because this test uses a
# non-routable server (192.0.2.1 should create a socket OK), these tests
# fire before the send/recv and return an error hash.
# -----------------------------------------------------------------------

# Note: the feature validation in query_xml loops over each feature
# after building the socket. On systems where socket() fails against
# 192.0.2.1 for any reason, these tests are still valid — they'd just
# return the socket-error response instead. We guard with a skip check.

SKIP: {
    # Quick probe: can we create a UDP socket at all?
    my $can_socket = eval {
        use Socket;
        socket(my $fh, PF_INET, SOCK_DGRAM, getprotobyname('udp'))
            or die "socket: $!";
        close($fh);
        1;
    };
    skip 'Cannot create UDP socket — skipping feature-code-in-xml tests', 14 unless $can_socket;

    for my $bad_feat (qw(2 0 1 500 999)) {
        my $na = make_na();
        my $resp = $na->query_xml('203.0.113.1', $bad_feat, '1');
        ok(defined $resp->{error}, "XML: invalid feature $bad_feat returns an error");
        like($resp->{error}, qr/invalid/, "XML: invalid feature $bad_feat error mentions 'invalid'");
    }

    # Mixed list: valid + invalid — the invalid one triggers the early return
    {
        my $na = make_na();
        my $resp = $na->query_xml('203.0.113.1', '3,999', '1');
        ok(defined $resp->{error}, 'XML: mixed valid+invalid feature list returns an error');
        like($resp->{error}, qr/999.*invalid|invalid.*999/i,
            'XML: error message identifies the bad feature code');
    }

    # Non-numeric feature
    {
        my $na = make_na();
        my $resp = $na->query_xml('203.0.113.1', 'abc', '1');
        ok(defined $resp->{error}, 'XML: non-numeric feature returns an error');
    }

    # Feature at exactly min boundary (3) should NOT error here
    # (it would proceed to send/recv and time out — not an early-exit error)
    {
        my $na = NetAcuity_API->new(server_addr => '192.0.2.1', api_id => 1, timeout => 0.1);
        my $resp = $na->query_xml('203.0.113.1', '3', '1');
        unlike($resp->{error} // '', qr/request for feature 3 is invalid/i,
            'XML: feature 3 (valid minimum) does not trigger feature-code error');
    }
}

# -----------------------------------------------------------------------
# transaction_id containing a wire-protocol-breaking character is rejected
# before any network activity. The request template embeds transaction_id
# in single-quoted XML attributes (trans-id='$transaction_id'), so a bare
# single quote breaks out of the attribute just as much as '"', '<', '>',
# '&' do — all five must be rejected.
# -----------------------------------------------------------------------
{
    my $na = make_na();
    for my $bad_char (q{'}, q{"}, '<', '>', '&') {
        my $resp = $na->query_xml('203.0.113.1', '3', "abc${bad_char}def");
        ok(defined $resp->{error}, "XML: transaction_id containing '$bad_char' returns an error");
        like($resp->{error}, qr/disallowed character/i, "XML: transaction_id containing '$bad_char' error message");
    }
}

# -----------------------------------------------------------------------
# Out-of-range api_id is rejected at query time (not just stored as-is by
# the constructor/accessor — query_xml must itself refuse to send)
# -----------------------------------------------------------------------
{
    my $na = NetAcuity_API->new(server_addr => '192.0.2.1', api_id => 128, timeout => 0);
    my $resp = $na->query_xml('203.0.113.1', '3', '1');
    ok(defined $resp->{error}, 'XML: api_id 128 (above max) rejected at query time');
    like($resp->{error}, qr/Invalid API ID/i, 'XML: api_id 128: correct error message');
}
{
    my $na = NetAcuity_API->new(server_addr => '192.0.2.1', api_id => -1, timeout => 0);
    my $resp = $na->query_xml('203.0.113.1', '3', '1');
    ok(defined $resp->{error}, 'XML: api_id -1 (below min) rejected at query time');
    like($resp->{error}, qr/Invalid API ID/i, 'XML: api_id -1: correct error message');
}

# -----------------------------------------------------------------------
# transaction_id is threaded through correctly in all pre-network errors
# -----------------------------------------------------------------------
{
    my $na = NetAcuity_API->new(server_addr => '');
    my $resp = $na->query_xml('203.0.113.1', '3', 'MYTX');
    is($resp->{'trans-id'}, 'MYTX', 'custom transaction_id appears in error response');
}

# -----------------------------------------------------------------------
# Verify query_xml sets xml_response before returning, and that a
# dynamic value (the query IP) containing an XML-breaking character is
# safely escaped rather than corrupting the built error XML.
# -----------------------------------------------------------------------
{
    my $na = make_na();
    $na->xml_response(undef);
    $na->query_xml(undef, '3', '1');
    ok(defined $na->xml_response(), 'xml_response set even on early-exit error path');
}
{
    my $na = make_na();
    my $resp = $na->query_xml('203.0.113.1" foo="bar', '3', '1');
    ok(defined $resp->{error}, 'query IP containing a double-quote is rejected, not injected verbatim');
    unlike($na->xml_response(), qr/foo="bar"/, 'query IP containing a double-quote is escaped in the built XML');
}
