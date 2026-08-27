use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'NetAcuity_API',
    VERSION          => 'v7.0.0',
    ABSTRACT         => 'Perl client for the NetAcuity IP intelligence server',
    AUTHOR           => 'Digital Envoy',
    LICENSE          => 'apache_2_0',
    MIN_PERL_VERSION => '5.010',
    PREREQ_PM        => {
        'Socket'          => 0,
        'XML::LibXML'     => 0,
        'NetAddr::IP'     => 0,
    },
    TEST_REQUIRES    => {
        'Test::More'      => 0,
        'IO::Socket::INET'=> 0,
    },
    META_MERGE       => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/netacuity/netacuity-client-api-perl.git',
                web  => 'https://github.com/netacuity/netacuity-client-api-perl',
            },
            bugtracker => {
                web => 'https://github.com/netacuity/netacuity-client-api-perl/issues',
            },
        },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
    clean => { FILES    => 'NetAcuity_API-*' },
);
