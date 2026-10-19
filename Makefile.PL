use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Mojolicious::Plugin::FormRequest',
    VERSION_FROM     => 'lib/Mojolicious/Plugin/FormRequest.pm',
    ABSTRACT         => 'Laravel-style form request validation for Mojolicious',
    AUTHOR           => 'Thomas <thomas@example.com>',
    LICENSE          => 'perl',
    MIN_PERL_VERSION => '5.016',
    PREREQ_PM        => {
        'Mojolicious' => '9.0',
        'DBI'         => '1.600',
    },
    TEST_REQUIRES => {
        'Test::More'  => '1.0',
        'Test::Mojo'  => '0',
        'DBD::SQLite' => '0',
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/yourname/mojolicious-plugin-formrequest.git',
                web  => 'https://github.com/yourname/mojolicious-plugin-formrequest',
            },
            bugtracker => {
                web => 'https://github.com/yourname/mojolicious-plugin-formrequest/issues',
            },
        },
    },
);
