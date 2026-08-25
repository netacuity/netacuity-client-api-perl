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

# Tests a genuine socket() creation failure. CORE::GLOBAL::socket must be
# overridden BEFORE NetAcuity_API.pm is compiled (require'd) -- a
# CORE::GLOBAL override only affects code compiled after it's installed,
# so this override lives in its own file/BEGIN block rather than being
# added to a file that already loaded NetAcuity_API for other tests.
use strict;
use warnings;
use Test::More;

BEGIN {
    *CORE::GLOBAL::socket = sub { return 0 };   # force every socket() call to fail
}

use lib 'lib', 'perl';
eval { require NetAcuity_API };
if ($@) {
    plan skip_all => "NetAcuity_API failed to load: $@";
}

plan tests => 2;

# -----------------------------------------------------------------------
# query_xml surfaces the socket() failure through its error hash, not an
# uncaught die (query_xml wraps its socket work in eval).
# -----------------------------------------------------------------------
{
    my $na = NetAcuity_API->new(server_addr => '192.0.2.1', api_id => 1, timeout => 1);
    my $resp = $na->query_xml('203.0.113.1', '3', '1');
    ok(defined $resp->{error}, 'socket() failure: query_xml returns an error hash, not a die');
    like($resp->{error}, qr/Cannot create UDP socket/i, 'socket() failure: query_xml error message set');
}
