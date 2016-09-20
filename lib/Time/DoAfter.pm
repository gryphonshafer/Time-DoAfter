package Time::DoAfter;
# ABSTRACT: Wait before doing by label contoller singleton

use strict;
use warnings;

use Carp 'croak';
use Time::HiRes qw( time sleep );

# VERSION

sub _input_handler {
    my ( $input, $set ) = ( {}, {} );

    my $push_input = sub {
        $input->{ $set->{label} || '_label' } = {
            wait => $set->{wait},
            do   => $set->{do},
        };
        $set = {};
    };

    while (@_) {
        my $thing = shift;
        my $type  =
            ( ref $thing eq 'CODE' ) ? 'do' :
            ( ref $thing eq 'ARRAY' or not ref $thing and defined $thing and $thing =~ m/^[\d\.]+$/ ) ? 'wait' :
            ( not ref $thing and defined $thing and $thing !~ m/^[\d\.]+$/ ) ? 'label' : 'error';

        croak('Unable to understand input provided; at least one thing provided is not a proper input')
            if ( $type eq 'error' );

        $push_input->() if ( exists $set->{$type} );
        $set->{$type} = $thing;
    }

    $push_input->();
    return $input;
}

{
    my $singleton;

    sub new {
        return $singleton if ($singleton);
        shift;

        my $self = bless( _input_handler(@_), __PACKAGE__ );
        $singleton = $self;
        return $self;
    }
}

sub do {
    my $self       = shift;
    my $input      = _input_handler(@_);
    my $total_wait = 0;

    for my $label ( keys %$input ) {
        $input->{$label}{wait} //= $self->{$label}{wait} // 0;
        $input->{$label}{do} ||= $self->{$label}{do} || sub {};

        if ( $self->{$label}{last} ) {
            my $wait;
            if ( ref $self->{$label}{wait} ) {
                my $min = $self->{$label}{wait}[0] // 0;
                my $max = $self->{$label}{wait}[1] // 0;
                $wait = rand( $max - $min ) + $min;
            }
            else {
                $wait = $self->{$label}{wait};
            }

            my $sleep = $wait - ( time - $self->{$label}{last} );
            if ( $sleep > 0 ) {
                $total_wait += $sleep;
                sleep($sleep);
            }
        }

        $self->{$label}{last} = time;
        $self->{$label}{$_}   = $input->{$label}{$_} for ( qw( do wait ) );

        push( @{ $self->{history} }, {
            label => $label,
            do    => $self->{$label}{do},
            wait  => $self->{$label}{wait},
            time  => time,
        } );

        $self->{$label}{do}->();
    }

    return $total_wait;
}

sub now {
    return time;
}

sub last {
    my ( $self, $label, $time ) = @_;

    my $value_ref = ( defined $label ) ? \$self->{$label}{last} : \$self->history( undef, 1 )->[0]{time};
    $$value_ref = $time if ( defined $time );

    return $$value_ref;
}

sub history {
    my ( $self, $label, $last ) = @_;

    my $history = $self->{history};
    $history = [ grep { $_->{label} eq $label } @$history ] if ($label);
    $history = [ grep { defined } @$history[ @$history - $last - 1, @$history - 1 ] ] if ( defined $last );

    return $history;
}

1;
__END__
=pod

=begin :badges

=for markdown
[![Build Status](https://travis-ci.org/gryphonshafer/Time-DoAfter.svg)](https://travis-ci.org/gryphonshafer/Time-DoAfter)
[![Coverage Status](https://coveralls.io/repos/gryphonshafer/Time-DoAfter/badge.png)](https://coveralls.io/r/gryphonshafer/Time-DoAfter)

=end :badges

=head1 SYNOPSIS

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

    my $current_time  = $tda0->now;
    my $last_time     = $tda0->last('label');
    my $new_last_time = $tda0->last( 'label', time );

    my $all_history   = $tda0->history;
    my $label_history = $tda0->history('label');
    my $last_5_label  = $tda0->history( 'label', 5 );

=head1 DESCRIPTION

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

=head2 Multiple Concurrent Labels

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

=head1 METHODS

The following are available methods:

=head2 new

This will instantiate or return a singleton object, off which you can call
C<do> and do things and stuff.

    my $tda = Time::DoAfter->new;

Alternatively, you can pass C<new> a list comprising of up to 3 things multiple
times over. Those 3 things are, in any order: label, wait, and do. Any of these
can be left undefined.

    my $tda1 = Time::DoAfter->new( 'label', [ 0.9, 2.3 ] );
    my $tda2 = Time::DoAfter->new(
        'label_a', 0.5, undef,
        'label_b', undef, sub {},
    );

These will setup defaults for when you call C<do>.

=head2 do

This will do things and stuff, after maybe waiting, of course. This method
can accept 3 things, which are, in any order: label, wait, and do.

    $tda->do( 'things', 2, \&do_things );
    $tda->do( \&do_stuff, 'stuff', [ 0.5, 1.5 ] );

If you don't specify some input to C<do>, it'll attempt to do the right thing
based on what you provided to C<new>.

This method will return a float indicating the sum time that C<do> waited for
the particular call.

=head2 now

Returns the current time (floating-point value) in seconds since the epoch.

    my $current_time = $tda->now;

=head2 last

Returns the last time (floating-point value in seconds since the epoch) when
the last "do" was done for a given label.

    my $last_time = $tda->last('things');

C<last> can also act as a setter. If you pass in a time value, it will set the
last time of the label to that time.

    $tda->last( 'things', time );

=head2 history

After calling C<do> a few times, this library will build up a history of doing
things. If you want to review that history, call C<history>. It will return
an arrayref of hashrefs, where the keys of each hashref are:
label, do, wait, and time. (Time in this case is when that do was done.)
You can also specify the number of most recent history events to return.

    my $all_history    = $tda->history;
    my $things_history = $tda->history('things');
    my $last_5_things  = $tda->history( 'things', 5 );

    my $last_thing      = pop @$last_5_things;
    my $last_thing_when = $last_thing->{time};

=head1 How Time Works

If you specify a time to wait that's an integer or floating point, that value
will get used for the wait calculation. If instead you provide an arrayref,
the library expects it to contain two numbers (integer or floating point).
The library will pick a random floating point number between these two values.

If you don't specify a wait, the library will assume a wait of zero.

=head1 DIRECT DEPENDENCIES

L<Time::HiRes>.

=head1 SEE ALSO

You can look for additional information at:

=for :list
* L<GitHub|https://github.com/gryphonshafer/Time-DoAfter>
* L<CPAN|http://search.cpan.org/dist/Time-DoAfter>
* L<MetaCPAN|https://metacpan.org/pod/Time::DoAfter>
* L<AnnoCPAN|http://annocpan.org/dist/Time-DoAfter>
* L<Travis CI|https://travis-ci.org/gryphonshafer/Time-DoAfter>
* L<Coveralls|https://coveralls.io/r/gryphonshafer/Time-DoAfter>
* L<CPANTS|http://cpants.cpanauthors.org/dist/Time-DoAfter>
* L<CPAN Testers|http://www.cpantesters.org/distro/T/Time-DoAfter.html>

=cut
