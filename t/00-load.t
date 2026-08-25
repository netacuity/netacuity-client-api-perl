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

# Support both current layout (perl/) and future idiomatic layout (lib/)
use lib 'lib', 'perl';

eval { require NetAcuity_API };
if ($@) {
    plan skip_all => "NetAcuity_API failed to load (check CPAN dependencies: Socket6, XML::LibXML, NetAddr::IP): $@";
}

plan tests => 3;

use_ok('NetAcuity_API');

ok(defined $NetAcuity_API::VERSION,              'VERSION constant is defined');
ok(defined NetAcuity_API::MAX_RESPONSE_SIZE(),       'MAX_RESPONSE_SIZE constant is defined');
