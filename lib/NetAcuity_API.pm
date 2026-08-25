package NetAcuity_API;
 ##**********************************************************************
 # File:           NetAcuity_API.pm
 # Author:         Digital Envoy
 # Version:        v7.0.0
 # Date:           2026-07-14
 #
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
 #
 #  Description:
 #    These functions allow a developer to access the NetAcuity Databases.
 #    The documentation is below in the POD form.
 #    Use pod2html or pod2man to format the POD documentation.
 #
 ##**********************************************************************

# See the bottom of this file for the POD documentation.  Search for the
# string '=head'.
#
# You can run this file through either pod2man or pod2html to produce
# documentation in manual or html file format.
#
# Documentation:  https://docs.netacuity.com/

use strict;
use warnings;

our $VERSION = 'v7.0.0';

use constant {
    MAX_RESPONSE_SIZE       => 1500,
};

use Socket qw(AF_INET AF_INET6 PF_INET PF_INET6 SOCK_DGRAM
              inet_aton inet_pton sockaddr_in pack_sockaddr_in6);
use XML::LibXML;
use NetAddr::IP::Util;

## _valid_query_ip returns true if $addr is a well-formed IPv4 or IPv6
## address literal.
sub _valid_query_ip {
    my ($addr) = @_;
    return 0 unless defined $addr;
    return 1 if defined inet_pton(AF_INET, $addr);
    return 1 if defined inet_pton(AF_INET6, $addr);
    return 0;
}

## _ips_equal returns true if $a and $b denote the same IP address,
## comparing parsed addresses rather than raw text so a
## differently-formatted-but-equal IPv6 literal (e.g. compressed vs.
## expanded) still matches. A malformed value is never treated as equal
## to anything.
sub _ips_equal {
    my ($a, $b) = @_;
    return 0 unless defined $a && defined $b;

    my $packed_a4 = inet_pton(AF_INET, $a);
    my $packed_b4 = inet_pton(AF_INET, $b);
    return ($packed_a4 eq $packed_b4) if defined $packed_a4 && defined $packed_b4;

    my $packed_a6 = inet_pton(AF_INET6, $a);
    my $packed_b6 = inet_pton(AF_INET6, $b);
    return ($packed_a6 eq $packed_b6) if defined $packed_a6 && defined $packed_b6;

    return 0;
}

## _xml_escape escapes the characters that are meaningful inside an XML
## attribute value (& < > " '), so untrusted values (query IP, feature
## codes, error text, etc.) can be interpolated into a built XML string
## without breaking the markup or injecting attributes/elements.
sub _xml_escape {
    my ($value) = @_;
    return '' unless defined $value;
    $value =~ s/&/&amp;/g;
    $value =~ s/</&lt;/g;
    $value =~ s/>/&gt;/g;
    $value =~ s/"/&quot;/g;
    $value =~ s/'/&apos;/g;
    return $value;
}

## Create a new NetAcuity_API Instance
sub new  {
    my $class = shift;
    my %settings = @_;
    my $server = $settings{'server_addr'};
    my $port = $settings{'server_port'};
    my $api_id = $settings{'api_id'};
    my $timeout = $settings{'timeout_seconds'};
    $timeout = $settings{'timeout'} if !defined $timeout;
    my $type = $settings{'type'};
    my $stream_type;
    my $xml_query;
    my $xml_response;
    my $addr_family = AF_INET;
    my $error_msg = "";

    if (!(defined $type)) { $type = "udp"; }
    # defined variables
    ## Set up default query connection type of udp
    if ($type ne "udp") {
        $type = "udp";
    };

    if (!(defined $port)) { $port = 5400; }
    ## Set up default ports
    if ($port eq "") {
       $port = 5400;
    }

    ## Set up stream type
    if ($type eq "udp") { $stream_type = SOCK_DGRAM; }

    ## Set up default timeout
    if (!(defined $timeout)) { $timeout = 2; }
    if ($timeout eq "") { $timeout = 2; }

    if (!(defined $api_id)) { $api_id = 0; }
    if ($api_id eq "") { $api_id = 0; }

    if (index($server, ':') == -1)
    {
       ## IPv4 Address
       $addr_family = AF_INET;
    }
    else
    {
       $addr_family = AF_INET6;
    }

    my $self = bless {
       'server_addr'=>$server,
       'server_port'=>$port,
       'api_id'=>$api_id,
       'timeout_seconds'=>$timeout,
       'type'=>$type,
       'stream_type'=>$stream_type,
       'xml_query'=>$xml_query,
       'xml_response'=>$xml_response,
       'raw_response'=>undef,
       'addr_family'=>$addr_family,
       'error_msg'=>$error_msg,
    }, $class;
    return $self;
}

sub server_info {
    my $self = shift;
    return $self->{'server_addr'};
}

sub server_addr {
    my $self = shift;
    my $server_addr = shift;
    $self->{'server_addr'} = $server_addr if defined $server_addr;
    if (index($self->{'server_addr'}, ':') == -1)
    {
       ## IPv4 Address
       $self->{'addr_family'} = AF_INET;
    }
    else
    {
       $self->{'addr_family'} = AF_INET6;
    }
    return $self->{'server_addr'};
}


sub server_port {
    my $self = shift;
    my $server_port = shift;
    $self->{'server_port'} = $server_port if defined $server_port;
    return $self->{'server_port'};
}

sub api_id {
    my $self = shift;
    my $api_id = shift;
    $self->{'api_id'} = $api_id if defined $api_id;
    return $self->{'api_id'};
}

sub error_msg {
    my $self = shift;
    my $error_msg = shift;
    $self->{'error_msg'} = $error_msg if defined $error_msg;
    return $self->{'error_msg'};
}

## timeout is a working alias for timeout_seconds(), retained so existing
## callers that pass/read 'timeout' keep working.
sub timeout {
    my $self = shift;
    my $timeout = shift;
    $self->{'timeout_seconds'} = $timeout if defined $timeout;
    return $self->{'timeout_seconds'};
}

## timeout_seconds is the preferred access method for the query timeout,
## in seconds.
sub timeout_seconds {
    my $self = shift;
    my $timeout = shift;
    $self->{'timeout_seconds'} = $timeout if defined $timeout;
    return $self->{'timeout_seconds'};
}

sub stream_type {
    my $self = shift;
    my $stream_type = shift;
    $self->{'stream_type'} = $stream_type if defined $stream_type;
    return $self->{'stream_type'};
}

sub type {
    my $self = shift;
    my $type = shift;
    if (defined $type) {
        $self->{'type'} = $type ;
        ## Set up stream type (only udp supported)
        if ($type eq "udp") {
            $self->stream_type(SOCK_DGRAM);
            $self->server_port(5400);
        }
        else {
            warn "Only UDP supported.\n";
            $self->stream_type(SOCK_DGRAM);
            $self->server_port(5400);
        }
    }
    return $self->{'type'};
}

## _open_socket creates a UDP socket appropriate for $server (PF_INET or
## PF_INET6 depending on whether $server is an IPv4 or IPv6 address), and
## connects it to $server:$port. Connecting restricts the OS to only deliver
## datagrams from $server on this socket, rejecting spoofed/stray packets
## from any other source at the kernel level.
## Returns the socket handle on success, or undef on failure with
## error_msg set on $self.
sub _open_socket {
    my $self = shift;
    my ($server, $port) = @_;
    my $sh;
    my $family = (index($server, ':') == -1) ? PF_INET : PF_INET6;

    if (!socket($sh, $family, $self->{'stream_type'}, getprotobyname($self->{'type'})))
    {
        $self->{'error_msg'} = "Cannot create UDP socket to $server:$port";
        return undef;
    }

    my $dest;
    if ($family == PF_INET) {
        my $host = inet_aton($server);
        if (!defined $host) {
            close($sh);
            $self->{'error_msg'} = "Invalid server IP address: $server";
            return undef;
        }
        $dest = sockaddr_in($port, $host);
    }
    else {
        my $host = inet_pton(AF_INET6, $server);
        if (!defined $host) {
            close($sh);
            $self->{'error_msg'} = "Invalid server IP address: $server";
            return undef;
        }
        $dest = pack_sockaddr_in6($port, $host);
    }

    if (!connect($sh, $dest)) {
        close($sh);
        $self->{'error_msg'} = "Cannot connect UDP socket to $server:$port";
        return undef;
    }

    return $sh;
}

## xml_query is an access method for the XML query that was built.
sub xml_query {
    my $self = shift;
    my $xml_query = shift;
    $self->{'xml_query'} = $xml_query if defined $xml_query;
    return $self->{'xml_query'};
}

## xml_response is an access method for the XML query that was built.
sub xml_response {
    my $self = shift;
    my $xml_response = shift;
    $self->{'xml_response'} = $xml_response if defined $xml_response;
    return $self->{'xml_response'};
}

## raw_response is an access method for the last raw, unparsed XML response
## string received from the NetAcuity Server via query_xml. It always holds
## genuine wire bytes from the server, never a fabricated/synthetic body: it
## is set as soon as real response data is received, whether that data is
## ultimately accepted or rejected (e.g. a transaction-ID/IP echo mismatch),
## and is left undef only when no genuine response bytes were ever received
## (e.g. a validation failure before the query was sent, or a timeout).
sub raw_response {
    my $self = shift;
    my $raw_response = shift;
    $self->{'raw_response'} = $raw_response if defined $raw_response;
    return $self->{'raw_response'};
}

## xml_field_order returns the field names from the most recent xml_parse()
## call, in the order they appeared in the response (unlike a hash, which
## has no defined iteration order).
sub xml_field_order {
    my $self = shift;
    return @{$self->{'xml_field_order'} || []};
}


## _error_response builds a "<response/>" error string in the standard wire
## attribute order (trans-id, then ip -- each included only when known),
## with all interpolated values escaped to prevent XML injection; stores it
## as xml_response(); parses it via xml_parse() into a fields hash; and
## returns that hash ref -- the same "named fields" shape query_xml()
## returns on success. Does not touch raw_response() -- callers that
## already received genuine response bytes must set that separately before
## calling this.
sub _error_response {
    my $self = shift;
    my ($transaction_id, $query_ip, $error_text) = @_;
    my $xml = '<response';
    $xml .= ' trans-id="' . _xml_escape($transaction_id) . '"' if defined $transaction_id;
    $xml .= ' ip="' . _xml_escape($query_ip) . '"' if defined $query_ip;
    $xml .= ' error="' . _xml_escape($error_text) . '"';
    $xml .= ' />';
    $self->xml_response($xml);
    my %fields;
    $self->xml_parse(\%fields);
    return \%fields;
}

#######################################################################
##
## query_xml() queries the feature codes passed and returns the response
##             as a hash ref of named fields, parsed from the underlying
##             XML. The raw XML string remains available afterwards via
##             xml_response().
## Parameters:
##   query_ip - IP address to query in dotted notation (eg. 203.0.113.1)
##   feature_codes - Comma separated list of feature codes to query (eg. 3,7,16)
##   transaction_id - caller-supplied transaction identifier; echoed back
##                     by the server and verified against the response
##
## Returns:
##   A hash ref of the response's named fields (e.g. {country => 'usa'}).
##   On error the hash ref will contain an 'error' key with the error
##   message.
##
## Example Use:  $netacuity = new NetAcuity_API(...);
##               $resp = $netacuity->query_xml("203.0.113.1", "3,7,16", "txn-001");
##               print "Country = $resp->{'country'}\n";
#######################################################################
sub query_xml {
    my $self = shift;
    my $query_ip = shift;
    my $feature_codes = shift;
    my $transaction_id = shift;
    my $rbits;
    my $wbits;
    my $ebits;
    $self->{'raw_response'} = undef;   # only set again once genuine bytes arrive

    if (not defined $transaction_id) {
        return $self->_error_response(undef, undef, "Transaction ID must be specified.");
    }
    if ($transaction_id =~ /['"<>&]/) {
        return $self->_error_response(undef, undef, "Invalid transaction ID: contains disallowed character");
    }

    ##########
    ### Deal with FATAL errors first
    ##########
    if (not defined $query_ip) {
        return $self->_error_response($transaction_id, undef, "IP Address not specified in query");
    }
    if (!_valid_query_ip($query_ip)) {
        return $self->_error_response($transaction_id, $query_ip, "Invalid query IP address: $query_ip");
    }
    if ($self->{'server_addr'} eq "") {
        return $self->_error_response($transaction_id, $query_ip, "NetAcuity Server address not set");
    }
    if (($self->{'api_id'} !~ /^\d+$/) || ($self->{'api_id'} < 0) || ($self->{'api_id'} > 127))
    {
        return $self->_error_response($transaction_id, $query_ip, "Invalid API ID: " . $self->{'api_id'});
    }

    my $server  = $self->{'server_addr'};
    my $port    = $self->{'server_port'};
    my $api_id  = $self->{'api_id'};

    ## Create a socket // this should be either pf_inet or pf_inet6 depending on the server ip address
    ## _open_socket() also connects it to $server:$port.
    my $sh = $self->_open_socket($server, $port);
    if (!defined $sh) {
        return $self->_error_response($transaction_id, $query_ip, $self->{'error_msg'});
    }

    ## Everything from here on touches the socket, so it's wrapped in an
    ## eval: a bare 'return' below only exits this eval block (not
    ## query_xml itself), guaranteeing close($sh) below always runs, even
    ## on an unexpected exception. Each branch stores its intended return
    ## value in $result (declared outside the eval) rather than returning
    ## directly, then the single 'return $result' after cleanup is what
    ## actually returns from query_xml.
    my $result;
    eval {
        ## Send query to the server
        my $built_query = "<request trans-id='$transaction_id' api-id='$api_id' ip='$query_ip' >";
        my @features = split(/\,/, $feature_codes);
        foreach my $feat (@features) {
            # Check to make sure the db to be queried < 100 and >= 3.
            if (($feat !~ /^\d+$/) || ($feat >= 100) || ($feat < 3))
            {
                $result = $self->_error_response($transaction_id, $query_ip, "request for feature $feat is invalid");
                return;
            }

            $built_query .= "<query db='$feat'/>";
        }
        $built_query .= "</request>";

        $self->xml_query($built_query);

        send($sh, $self->xml_query, 0);

        ## Initialize response
        ## Must be initialized to the maxsize that will be received into the buffer
        ## In this case 255 bytes...
        my $response = '';

        my $packetNumReceived = 0;
        my $packetsToReceive = 100;
        my $completeResponse = "";
        my $lastReceived = 0;

        while ($packetNumReceived < $packetsToReceive) {
            ## Set up bits for select
            $rbits = $wbits = $ebits = "";
            vec($rbits, fileno($sh), 1) = 1;
            $ebits = $rbits | $wbits;

            ## Wait here until data is ready, we timeout, or select() itself errors
            my $nfound = select($rbits, $wbits, $ebits, $self->{'timeout_seconds'});
            if ($nfound == 0)
            {
                $result = $self->_error_response($transaction_id, $query_ip, "timeout awaiting response");
                return;
            }
            if ($nfound < 0)
            {
                $result = $self->_error_response($transaction_id, $query_ip,
                    "Error waiting for response from NetAcuity Server: $!");
                return;
            }

            ## Pull data off the socket
            recv($sh, $response, MAX_RESPONSE_SIZE, 0);

            unless ($response) {
                $result = $self->_error_response($transaction_id, $query_ip, "timeout awaiting response");
                return;
            }

            $packetNumReceived = substr($response, 0, 2);
            $packetsToReceive  = substr($response, 2, 2);

            if ($packetNumReceived - 1 != $lastReceived) {
                $result = $self->_error_response($transaction_id, $query_ip, "API: packets out of order");
                return;
            }

            $lastReceived = $packetNumReceived;
            $completeResponse .= substr($response, 4, -1);
        }

        $self->xml_response($completeResponse);

        ## Genuine bytes have now arrived -- from here on, raw_response()
        ## reflects them whether the response is ultimately accepted or
        ## rejected below.
        $self->raw_response($completeResponse);

        ## Verify the response is in sync with this request before accepting it.
        ## A missing trans-id/ip (parse failure, missing root, or a genuinely
        ## absent attribute) is itself treated as a mismatch, not skipped.
        my $verify_dom = eval { XML::LibXML->load_xml(string => $completeResponse) };
        my ($response_node) = $verify_dom ? $verify_dom->findnodes("/response") : ();
        my $resp_trans_id = $response_node ? $response_node->getAttribute('trans-id') : undef;
        my $resp_ip       = $response_node ? $response_node->getAttribute('ip')       : undef;

        if (!defined $resp_trans_id || $resp_trans_id ne $transaction_id) {
            my $got = defined $resp_trans_id ? $resp_trans_id : '(missing)';
            $result = $self->_error_response($transaction_id, $query_ip,
                "Transaction ID mismatch: expected $transaction_id, got $got");
            return;
        }
        if (!defined $resp_ip || !_ips_equal($resp_ip, $query_ip)) {
            my $got = defined $resp_ip ? $resp_ip : '(missing)';
            $result = $self->_error_response($transaction_id, $query_ip,
                "Response IP address mismatch: expected $query_ip, got $got");
            return;
        }

        my %fields;
        $self->xml_parse(\%fields);
        $result = \%fields;
    };
    if ($@) {
        my $eval_error = $@;
        chomp $eval_error;
        $result = $self->_error_response($transaction_id, $query_ip, "Unexpected error during query: $eval_error");
    }
    close($sh) if $sh;
    return $result;
}

#######################################################################
##
## xml_parse() parses the elements of the most recently stored XML
##             response (xml_response()) into a passed hash. Each field
##             in the response becomes a hash key. query_xml() already
##             calls this internally and returns the parsed hash
##             directly, so most callers won't need to call this
##             separately -- it remains useful for re-parsing a
##             previously-stored xml_response().
## Parameters:
##   fields     - Hash in which to place parsed field names and values
##
## Returns:      1 on success, 0 if the stored XML could not be parsed
##               (error_msg is set to describe why).
##
## Example Use:  my %data;
##               $netacuity->query_xml("203.0.113.1", "3,7,16", "txn-001");
##               $netacuity->xml_parse(\%data);
##               print "Country = $data{'country'}\n";
##               print "Region  = $data{'region'}\n";
##
#######################################################################
sub xml_parse(\%)
{
   my $self = shift;
   my $fields = shift;
   my $dom = eval { XML::LibXML->load_xml(string => $self->xml_response()) };
   if (!$dom) {
       my $parse_error = $@;
       chomp $parse_error;
       $self->{'error_msg'} = "Unable to parse XML response: $parse_error";
       return 0;
   }
   $self->{'xml_field_order'} = [];
   foreach my $attribute ($dom->findnodes("/response/@*")) {
      my $fieldName = $attribute->nodeName;
      my $fieldValue = $attribute->value;
      $fields->{$fieldName} = $fieldValue;
      push @{$self->{'xml_field_order'}}, $fieldName;
   }
   return 1;
}



## Make Perl Happy!
1;

__END__

=head1 NAME

NetAcuity_API - Perl client for the NetAcuity IP intelligence server

=head1 SYNOPSIS

  use NetAcuity_API;

  my $na = NetAcuity_API->new(
      server_addr    => '192.0.2.1',
      api_id         => 75,           # your identifier, 0-127; default: 0
      timeout_seconds => 3,           # 'timeout' also accepted, as an alias
  );

  # XML query — supports multiple feature-codes per call, and returns
  # the parsed named fields directly.
  my $data = $na->query_xml('203.0.113.1', '3,7,26', 'txn-001');
  print "Country: $data->{country}\n";

=head1 DESCRIPTION

NetAcuity_API provides an interface to the NetAcuity Server using the
XML UDP query protocol, which supports querying multiple feature-codes
in one call; C<query_xml()> returns the response's named fields
directly.

Both IPv4 and IPv6 server addresses are supported.

=head1 CONSTRUCTOR

=head2 new(%options)

  my $na = NetAcuity_API->new(
      server_addr     => '192.0.2.1',   # required
      server_port     => 5400,          # default: 5400
      api_id          => 75,            # your identifier, 0-127; default: 0
      timeout_seconds => 2,             # default: 2; 'timeout' works too
  );

C<timeout_seconds> is the preferred name for the query timeout, in
seconds; C<timeout> is retained as a working alias for the same setting.

=head1 METHODS

=head2 query_xml($ip, $features, $transaction_id)

Query one or more feature-codes via XML UDP.  C<$features> is a
comma-separated list of integer feature-codes (e.g. C<"3,7,26">).
Returns a hash ref of the response's named fields.  On error the hash
ref will contain an C<error> key with the error message.  The raw XML
string remains available afterwards via C<xml_response()>.

=head2 xml_parse(\%hash)

Parse the most recent XML response (stored by C<query_xml>) into the
supplied hash reference.  Each XML attribute becomes a hash key.  Not
normally needed — C<query_xml> already returns the parsed fields
directly — but useful for re-parsing a previously-stored
C<xml_response()>.

=head1 FEATURE CODES

Feature-codes identify which NetAcuity database to query.  Valid
values are integers in the range 3–99.  The full list of supported
feature-codes and their response fields is available at:

  https://docs.netacuity.com/

=head1 DEPENDENCIES

  Socket
  XML::LibXML
  NetAddr::IP

=head1 SUPPORT

Technical Support is only available to those under active contract with
Digital Element. To contact Support, use the contact information provided
at contract initiation.

  https://docs.netacuity.com/

=head1 LICENSE

Copyright 2026 Digital Envoy, Inc.

Licensed under the Apache License, Version 2.0. See LICENSE in the
project root for the full license text, or:

  https://www.apache.org/licenses/LICENSE-2.0

=cut
