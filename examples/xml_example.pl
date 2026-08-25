#!/usr/bin/perl
###
### Query the NetAcuity Server for a specific IP address from multiple
### feature databases using the XML UDP query protocol (recommended).
###
### Version:  v7.0.0
### Date:     2026-06-22
###
### Copyright 2026 Digital Envoy, Inc.
###
### Licensed under the Apache License, Version 2.0 (the "License");
### you may not use this file except in compliance with the License.
### You may obtain a copy of the License at
###
###     https://www.apache.org/licenses/LICENSE-2.0
###
### Unless required by applicable law or agreed to in writing, software
### distributed under the License is distributed on an "AS IS" BASIS,
### WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
### See the License for the specific language governing permissions and
### limitations under the License.
###

sub usage {
print << "___END___";
### Usage:  xml_example.pl <server_ip> <query_ip> <feature_codes>
###   where:
###     <server_ip>     is the IP address of the NetAcuity Server
###     <query_ip>      is the IP address you wish to query about
###     <feature_codes> is a comma-separated list of feature codes to query
###
### Example:  xml_example.pl 192.0.2.1 203.0.113.1 26,33,35,93
###
___END___
exit(-1)
}

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use NetAcuity_API;

my $server_ip = $ARGV[0];
my $ip = $ARGV[1];
my $feature_codes = $ARGV[2];
if (!defined $server_ip || $server_ip eq "") { usage(); }
if (!defined $ip || $ip eq "") { usage(); }
if (!defined $feature_codes || $feature_codes eq "") { usage(); }
my $api_id = 75;
my $timeout_seconds = 3;
my $na = NetAcuity_API->new(server_addr=>$server_ip, api_id=>$api_id, timeout_seconds => $timeout_seconds);

## Query using the XML function -- query_xml() parses the response and
## returns the named fields directly, so no separate xml_parse() call
## is needed.
my $transaction_id = substr(rand(), 2);
my $results = $na->query_xml("$ip", "$feature_codes", "$transaction_id");

## Print results in the order they appeared in the response
print "ip = $results->{'ip'}\n";
print "trans-id = $results->{'trans-id'}\n";
foreach my $r ($na->xml_field_order())
{
    next if ($r eq "ip" || $r eq "trans-id");
    print "$r = $results->{$r}\n";
}
print "raw-response = " . $na->raw_response() . "\n";

## If any errors happened, "error" value of the hash will indicate the
## error string
if (defined $results->{"error"})
{
    print "Error: $results->{'error'}\n";
    exit(-1)
}
