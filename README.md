# NetAcuity Client API — Perl

Perl client library for querying the [NetAcuity](https://www.digitalelement.com/solutions/netacuity/) Server for IP geolocation and intelligence data via the XML UDP query protocol.

## Requirements

- **Perl** 5.10 or later
- A running **NetAcuity Server** (default port 5400, configurable)
- An **API ID** (customer-provided integer, range 0–127; default 0)
- CPAN modules: `XML::LibXML` (installed automatically — see Installation / Build below)

## Installation / Build

```bash
git clone https://github.com/netacuity/netacuity-client-api-perl.git
cd netacuity-client-api-perl
cpanm .
```

`cpanm` resolves and installs `XML::LibXML` automatically. If you don't have a C toolchain available (`XML::LibXML` compiles against libxml2), install a prebuilt package via your OS package manager instead:

| Module | Install (Debian/Ubuntu) | Install (RHEL/CentOS 8+) |
|---|---|---|
| `XML::LibXML` | `sudo apt-get install libxml-libxml-perl` | `sudo dnf install "perl(XML::LibXML)"` |

### Without installing (set PERL5LIB)

If you prefer to run examples directly from the repository without a system install, install just the dependencies and point `PERL5LIB` at the `lib/` directory:

```bash
cpanm --installdeps .
export PERL5LIB="$(pwd)/lib:$PERL5LIB"
```

## Quick Start

### XML UDP Query

The XML UDP protocol supports multiple feature codes in a single query.

```perl
use NetAcuity_API;

my $na = NetAcuity_API->new(
    server_addr     => '192.0.2.1',   # your NetAcuity Server IP
    api_id          => 75,            # your identifier, 0-127; default: 0
    timeout_seconds => 3,
);

my $data = $na->query_xml('203.0.113.1', '3,7,26', 'txn-001');

print "Country:  $data->{country}\n";
print "Region:   $data->{region}\n";
print "City:     $data->{city}\n";
print "Timezone: $data->{'timezone-name'}\n";

if (defined $data->{error}) {
    print "Error: $data->{error}\n";
}
```

## API Reference

### Constructor

```perl
my $na = NetAcuity_API->new(
    server_addr     => '192.0.2.1',   # NetAcuity Server IP (IPv4 or IPv6)
    server_port     => 5400,          # default: 5400
    api_id          => 75,            # your identifier, 0–127; default: 0
    timeout_seconds => 2,             # seconds to wait for response; default: 2
                                       # ('timeout' also accepted, as an alias)
);
```

### Methods

| Method | Description |
|---|---|
| `query_xml($ip, $features, $transaction_id)` | XML UDP query. `$features` is comma-separated feature codes (e.g. `"3,7,26"`). Returns a hash ref of the response's named fields (an `error` key is present on failure); `xml_field_order()` returns those field names in the order they appeared in the response (a hash has no defined order); the raw XML is also available via `xml_response()`, and the raw, unparsed response text via `raw_response()` (cleared at the start of every query, then set as soon as genuine response bytes are received — whether the response is ultimately accepted or rejected — never left holding a stale payload from an earlier query, even when reusing the same object). |
| `xml_parse(\%hash)` | Parses the most recent XML response into the supplied hash. Not normally needed — `query_xml` already returns the parsed fields directly. |
| `error_msg()` | Returns the error message from a socket-level failure (couldn't connect, timed out, etc.) on the most recent query, or empty string if none occurred. Validation/mismatch failures (invalid input, trans-id/IP mismatch, a DB-level error) are reported only through the returned hash's `error` key, not here — check that key too. |

## Feature Codes

For the complete, up-to-date list of feature codes and their response fields, see the [NetAcuity documentation](https://docs.netacuity.com/).

## Examples

Runnable examples are provided in the `examples/` directory:

```bash
# XML query — multiple feature codes
perl examples/xml_example.pl <server_ip> <query_ip> <feature_codes>
perl examples/xml_example.pl 192.0.2.1 203.0.113.1 26,33,35
```

## Running the Tests

```bash
# Requires Strawberry Perl on Windows, or system Perl with dependencies on Linux/macOS
perl Makefile.PL && make test

# Or run individual test files directly
perl t/01-constructor.t
perl t/05-xml-parse.t

# Or run the full suite with prove
prove -v t/
```

## Changelog

See [Changes](Changes) for release history.

## Support

Technical Support is only available to those under active contract with Digital Element. To contact Support, use the contact information provided at contract initiation.

- Documentation: [docs.netacuity.com](https://docs.netacuity.com/)
- Issues: [GitHub Issues](https://github.com/netacuity/netacuity-client-api-perl/issues)

## License

Copyright 2026 Digital Envoy, Inc.

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for the full license text.

This repository contains no third-party source code or binaries. Its runtime dependencies (`Socket`, `XML::LibXML`) are installed separately from CPAN by the end developer and are not redistributed with this module. Each is dual-licensed under the Artistic License or the GNU GPL; they are used unmodified, under the Artistic License option of each dual license.
