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

# Tests for xml_parse() — exercises the XML parsing logic independently
# of the network layer by pre-loading xml_response().
use strict;
use warnings;
use Test::More;

use lib 'lib', 'perl';
eval { require NetAcuity_API };
if ($@) {
    plan skip_all => "NetAcuity_API failed to load: $@";
}

# XML::LibXML must be loadable
eval { require XML::LibXML };
if ($@) {
    plan skip_all => "XML::LibXML not available: $@";
}

plan tests => 28;

sub make_na { NetAcuity_API->new(server_addr => '192.0.2.1') }

# -----------------------------------------------------------------------
# Self-closing response with a single attribute
# -----------------------------------------------------------------------
{
    my $na = make_na();
    $na->xml_response('<response country="usa" />');
    my %d;
    $na->xml_parse(\%d);
    is($d{country}, 'usa', 'parse: single attribute "country"');
}

# -----------------------------------------------------------------------
# Multiple attributes
# -----------------------------------------------------------------------
{
    my $na = make_na();
    $na->xml_response('<response country="usa" region="ca" city="san jose" />');
    my %d;
    $na->xml_parse(\%d);
    is($d{country}, 'usa',      'parse: country');
    is($d{region},  'ca',       'parse: region');
    is($d{city},    'san jose', 'parse: city with space');
}

# -----------------------------------------------------------------------
# Error attribute
# -----------------------------------------------------------------------
{
    my $na = make_na();
    $na->xml_response('<response error="DB Not Loaded" />');
    my %d;
    $na->xml_parse(\%d);
    is($d{error}, 'DB Not Loaded', 'parse: error attribute');
}

# -----------------------------------------------------------------------
# Numeric and float attributes
# -----------------------------------------------------------------------
{
    my $na = make_na();
    $na->xml_response('<response latitude="37.3861" longitude="-122.0839" metro-code="807" />');
    my %d;
    $na->xml_parse(\%d);
    is($d{latitude},    '37.3861',  'parse: latitude float');
    is($d{longitude},   '-122.0839','parse: negative longitude float');
    is($d{'metro-code'},'807',      'parse: hyphenated attribute name');
}

# -----------------------------------------------------------------------
# trans-id and ip attributes
# -----------------------------------------------------------------------
{
    my $na = make_na();
    $na->xml_response('<response trans-id="abc123" ip="203.0.113.1" country="gbr" />');
    my %d;
    $na->xml_parse(\%d);
    is($d{'trans-id'}, 'abc123', 'parse: trans-id attribute');
    is($d{ip},         '203.0.113.1','parse: ip attribute');
    is($d{country},    'gbr',    'parse: country alongside trans-id and ip');
}

# -----------------------------------------------------------------------
# Empty attribute value
# -----------------------------------------------------------------------
{
    my $na = make_na();
    $na->xml_response('<response country="usa" region="" />');
    my %d;
    $na->xml_parse(\%d);
    is($d{country}, 'usa', 'parse: country with empty sibling');
    is($d{region},  '',   'parse: empty string attribute value');
}

# -----------------------------------------------------------------------
# Typical geo response (feature-code 3 / Pulse)
# -----------------------------------------------------------------------
{
    my $na = make_na();
    $na->xml_response(
        '<response trans-id="1" ip="203.0.113.1" ' .
        'country="usa" region="ca" city="mountain view" ' .
        'conn-speed="broadband" country-cf="99" region-cf="80" city-cf="75" ' .
        'metro-code="807" latitude="37.386" longitude="-122.0838" ' .
        'country-code="3" region-code="7" city-code="12345" ' .
        'continent-code="3" two-letter-country="us" />'
    );
    my %d;
    $na->xml_parse(\%d);
    is($d{country},           'usa',          'geo: country');
    is($d{region},            'ca',           'geo: region');
    is($d{city},              'mountain view','geo: city');
    is($d{'conn-speed'},      'broadband',    'geo: conn-speed');
    is($d{'country-cf'},      '99',           'geo: country-cf');
    is($d{'metro-code'},      '807',          'geo: metro-code');
    is($d{'two-letter-country'}, 'us',        'geo: two-letter-country');
    is($d{'continent-code'},  '3',            'geo: continent-code');
}

# -----------------------------------------------------------------------
# Result hash is properly populated (not empty)
# -----------------------------------------------------------------------
{
    my $na = make_na();
    $na->xml_response('<response a="1" b="2" c="3" />');
    my %d;
    $na->xml_parse(\%d);
    is(scalar keys %d, 3, 'parse: correct number of keys in result hash');
}

# -----------------------------------------------------------------------
# Repeated calls overwrite the hash (merge behavior)
# -----------------------------------------------------------------------
{
    my $na = make_na();
    $na->xml_response('<response country="usa" />');
    my %d;
    $na->xml_parse(\%d);
    $na->xml_response('<response country="gbr" region="england" />');
    $na->xml_parse(\%d);
    is($d{country}, 'gbr',     'parse: second call overwrites existing key');
    is($d{region},  'england', 'parse: second call adds new key');
}

# -----------------------------------------------------------------------
# xml_parse doesn't care about element name — tests root attributes
# -----------------------------------------------------------------------
{
    my $na = make_na();
    # The XPath is "/response/@*" so the root element must be <response>
    $na->xml_response('<response foo="bar" baz="qux" />');
    my %d;
    $na->xml_parse(\%d);
    is($d{foo}, 'bar', 'parse: arbitrary attribute foo');
    is($d{baz}, 'qux', 'parse: arbitrary attribute baz');
}

# -----------------------------------------------------------------------
# Unicode / non-ASCII values
# -----------------------------------------------------------------------
{
    my $na = make_na();
    # City name with accent — XML::LibXML returns it as a decoded Perl unicode
    # string; xml_parse leaves it as-is (decoded text), not raw UTF-8 bytes.
    $na->xml_response('<response city="m&#x00fc;nchen" />');
    my %d;
    $na->xml_parse(\%d);
    ok(defined $d{city}, 'parse: unicode city value is defined');
    ok(length($d{city}) > 0, 'parse: unicode city value is non-empty');
}
