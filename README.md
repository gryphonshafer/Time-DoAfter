# NAME

Time::DoAfter - Wait before doing by label contoller singleton

# VERSION

version 1.09

[![test](https://github.com/gryphonshafer/Time-DoAfter/workflows/test/badge.svg)](https://github.com/gryphonshafer/Time-DoAfter/actions?query=workflow%3Atest)
[![codecov](https://codecov.io/gh/gryphonshafer/Time-DoAfter/graph/badge.svg)](https://codecov.io/gh/gryphonshafer/Time-DoAfter)

# SYNOPSIS

    use Time::DoAfter;

    my $tda0 = Time::DoAfter->new;
    my $tda1 = Time::DoAfter->new( 'label', [ 0.9, 2.3 ], sub {} );
    my $tda2 = Time::DoAfter->new(
        'label_a', 0.5, sub {},
        'label_b', 0.7, sub {},
    );

    $tda1->do;
    $tda2->do('label_b');
    $tda0->do( sub {} );
    $tda0->do( sub {}, 0.5 );
    $tda0->do( 'label', sub {} );
    $tda0->do( 'label', sub {}, 0.5 );

    my $total_wait = $tda1->do;

    my ( $time_since, $time_wait ) = $tda1->do( sub {} );

    my $current_time   = $tda0->now;
    my $last_time      = $tda0->last('label');
    my $new_last_time  = $tda0->last( 'label', time );

    my $all_history    = $tda0->history;
    my $label_history  = $tda0->history('label');
    my $last_5_label   = $tda0->history( 'label', 5 );

    my $label_sub      = $tda0->sub('label');
    my $new_label_sub  = $tda0->sub( 'label', sub {} );

    my $label_wait     = $tda0->wait('label');
    my $new_label_wait = $tda0->wait( 'label', [ 1.3, 2.1 ] );

    $tda0->wait_adjust( 'label', 2 );

# DESCRIPTION

This library provides a means to do something after waiting a specified period
of time since the previous invocation under the same something label. Also,
it's a singleton.

Let's say you have a situation where you want to do something every 2 seconds,
but that thing you want to do might take anywhere between 0.5 and 1.5 seconds
to accomplish. Basically, you want to wait for a period of time since the last
invocation such that the next invocation is 2 seconds after the previous.

    my $tda = Time::DoAfter->new(2);

    $tda->do( sub {} ); # pretend this first action takes 0.5 seconds to complete
    $tda->do( sub {} ); # this second action will wait 1.5 seconds before starting

Alternatively, let's say you're web scraping and you want to keep the requests
to a specific host separated by a random amount of time between 0.5 and 1.5
seconds.

    my $tda = Time::DoAfter->new( [ 0.5, 1.5 ] );
    $tda->do( sub { scrape_a_new_web_page($_) } ) for (@pages);

## Multiple Concurrent Labels

Conceptually, the library has the notion of "do" (the action, subroutine), "wait"
(the total time bewtween invocations), and "label" (the name given to the type
of invocation). These can be specified at singleton object instantiation or
later when you're wanting to invoke the action.

For example, let's say you're scraping two different web hosts. You'd like to
wait up to 2 seconds between each request for the first host and 3 seconds
between each request for the second host.

    my $tda = Time::DoAfter->new;

    $tda->do( 'host_1', 2, \&scrape_host_1 );
    $tda->do( 'host_2', 3, \&scrape_host_2 );

# METHODS

The following are available methods:

## new

This will instantiate or return a singleton object, off which you can call
`do` and do things and stuff.

    my $tda = Time::DoAfter->new;

Alternatively, you can pass `new` a list comprising of up to 3 things multiple
times over. Those 3 things are, in any order: label, wait, and do. Any of these
can be left undefined.

    my $tda1 = Time::DoAfter->new( 'label', [ 0.9, 2.3 ] );
    my $tda2 = Time::DoAfter->new(
        'label_a', 0.5, undef,
        'label_b', undef, sub {},
    );

These will setup defaults for when you call `do`.

## do

This will do things and stuff, after maybe waiting, of course. This method
can accept 3 things, which are, in any order: label, wait, and do.

    $tda->do( 'things', 2, \&do_things );
    $tda->do( \&do_stuff, 'stuff', [ 0.5, 1.5 ] );

If you don't specify some input to `do`, it'll attempt to do the right thing
based on what you provided to `new`.

This method will return a float indicating the sum time that `do` waited for
the particular call.

## now

Returns the current time (floating-point value) in seconds since the epoch.

    my $current_time = $tda->now;

## last

Returns the last time (floating-point value in seconds since the epoch) when
the last "do" was done for a given label.

    my $last_time = $tda->last('things');

`last` can also act as a setter. If you pass in a time value, it will set the
last time of the label to that time.

    $tda->last( 'things', time );

## history

After calling `do` a few times, this library will build up a history of doing
things. If you want to review that history, call `history`. It will return
an arrayref of hashrefs, where the keys of each hashref are:
label, do, wait, and time. (Time in this case is when that do was done.)
You can also specify the number of most recent history events to return.

    my $all_history    = $tda->history;
    my $things_history = $tda->history('things');
    my $last_5_things  = $tda->history( 'things', 5 );

    my $last_thing      = pop @$last_5_things;
    my $last_thing_when = $last_thing->{time};

## sub

Gets or sets the subroutine reference for a label's do action.

    my $label_sub     = $tda->sub('label');
    my $new_label_sub = $tda->sub( 'label', sub {} );

## wait

Gets or sets the wait time (explicit value or arrayref of range) for a label.

    my $label_wait     = $tda->wait('label');
    my $new_label_wait = $tda->wait( 'label', [ 1.3, 2.1 ] );

## wait\_adjust

This method lets you adjust the wait for a given label, adding to or subtracting
from the wait setting.

    $tda->wait( 'simple', 5 );         # simple now has a wait of 5 seconds
    $tda->wait_adjust( 'simple', 2 );  # simple now has a wait of 7 seconds
    $tda->wait_adjust( 'simple', -1 ); # simple now has a wait of 6 seconds

    $tda->wait( 'range', [ 1, 2 ] );  # range now has a wait of 1 to 2 seconds
    $tda->wait_adjust( 'range', 2 );  # range now has a wait of 3 to 5 seconds
    $tda->wait_adjust( 'range', -1 ); # range now has a wait of 2 to 4 seconds

# How Time Works

If you specify a time to wait that's an integer or floating point, that value
will get used for the wait calculation. If instead you provide an arrayref,
the library expects it to contain two numbers (integer or floating point).
The library will pick a random floating point number between these two values.

If you don't specify a wait, the library will assume a wait of zero.

# DIRECT DEPENDENCIES

[Time::HiRes](https://metacpan.org/pod/Time%3A%3AHiRes).

# SEE ALSO

You can look for additional information at:

- [GitHub](https://github.com/gryphonshafer/Time-DoAfter)
- [MetaCPAN](https://metacpan.org/pod/Time::DoAfter)
- [GitHub Actions](https://github.com/gryphonshafer/Time-DoAfter/actions)
- [Codecov](https://codecov.io/gh/gryphonshafer/Time-DoAfter)
- [CPANTS](http://cpants.cpanauthors.org/dist/Time-DoAfter)
- [CPAN Testers](http://www.cpantesters.org/distro/T/Time-DoAfter.html)

# AUTHOR

Gryphon Shafer <gryphon@cpan.org>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2016-2050 by Gryphon Shafer.

This is free software, licensed under:

    The Artistic License 2.0 (GPL Compatible)
