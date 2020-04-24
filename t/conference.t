package main;
use strict;
use warnings;
use utf8; # for test data

use Test::More;
use Test::Fatal;
#use Test::Act::Conference::FromConfig qw(config_handle);

use Act::Conference;

use Act::Config;


# Plain constructions

{
    my $conference = Act::Conference->new;
    isa_ok($conference,'Act::Conference',
           'Construct without any parameters');
}

{
    my $conference = Act::Conference->new(
        default_country  => 'uk',
        default_language => 'en',
        full_uri => URI->new('http://localhost:5000/demo/'),
        registration_open => 1,
        registration_max_attendees => 100,
    );
    isa_ok($conference,'Act::Conference',
           'Construct with all supported attributes');
}

{
    my $conference = Act::Conference->new(
        full_uri => URI->new('http://localhost:5000/demo/'),
    );
    isa_ok($conference,'Act::Conference',
           'Construct with an URI for full_uri');
}


# Construction with coercion


{
    my $conference = Act::Conference->new(
        full_uri => 'http://localhost:5000/demo/',
    );
    isa_ok($conference,'Act::Conference',
           'Construct with a string for full_uri');
}

# Error handling: Bad constructions

{
    like (
        exception {
            my $conference = Act::Conference->new(
                default_language => 'zz',
            ),
        },
        qr/ISO 639-1/,
        'Error handling: Invalid language dies, points to ISO 639-1',
    );
}

{
    like (
        exception {
            my $conference = Act::Conference->new(
                default_country => 'bay',
            ),
        },
        qr/ISO 3166-1/,
        'Error handling: Invalid country dies, points to ISO 3166-1',
    );
}

{
    use Act::Conference::Registration;
    like (
        exception {
            my $conference = Act::Conference->new(
                registration => Act::Conference::Registration->new(open => 'no')
            ),
        },
        qr/did not pass type constraint "Bool"/,
        "Error handling: [registration]open doesn't take 'no' as an answer"
    );
}

# Reading and writing a configuration file
{
    $Config = Act::Config::get_config('testing');
    my $conference = Act::Conference->from_config($Config);

    use Data::Printer { class => { expand       => 'all',
                                   show_methods => 'none',
                                   parents      => 0,
                                 },
                        colored => 1,
                      };
    isa_ok($conference,'Act::Conference','from config data');
    binmode STDERR, ':encoding(UTF-8)';
    p $conference;

    my $out;
    $conference->write_config(\$out);
    p $out;

    # now just randomly check some entries in the resulting config file
    like($out,qr!\[general\]  # in section [general]
                 [^\[]*?      # no other section
                 full_uri\s*=\s*http://localhost:5000/testing
                !sx,
         'full URI ok after roundtrip');
    like($out,qr/^languages\s*=\s*en\s*ru/m,
         'languages retained correctly');
    like($out,qr/^rooms \s* = \s*
                 r1 \s* r2 \s* r3$
                /mx,
         'Room identifiers complete, and sorted');
    like($out,qr/^
                 \[product_registration_price2\]\n
                 name_en \s* = \s* Reduced \s* price\n
                 name_ru \s* = \s* Сниженная \s* цена\n
                 amount \s* = \s* 2.71\n
                 promocode \s* = \s* "I'm \s* a \s* vip"\n
                /mx,
         'Examine a multilevel HoH structure');
}

done_testing;
