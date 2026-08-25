requires 'perl', '5.010';
requires 'Socket';
requires 'XML::LibXML';
requires 'NetAddr::IP';

on test => sub {
    requires 'Test::More';
    requires 'IO::Socket::INET';
};
