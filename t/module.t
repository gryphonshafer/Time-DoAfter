use strict;
use warnings;

use Test::Most;

use constant MODULE => 'Time::DoAfter';

BEGIN { use_ok(MODULE); }
require_ok(MODULE);

my @obj;
ok( push( @obj, MODULE->new ), MODULE . '->new' );
is( ref $obj[-1], MODULE, 'ref $object' );

ok( push( @obj, MODULE->new( sub {} ) ), MODULE . '->new( sub {} )' );
is( ref $obj[-1], MODULE, 'ref $object' );

ok( push( @obj, MODULE->new( 'label1', sub {} ) ), MODULE . '->new( sub {} )' );
is( ref $obj[-1], MODULE, 'ref $object' );

ok( push( @obj,
    MODULE->new( 'label2', sub {}, 2, 3, 'label3', sub {}, sub{}, 'label4', [ 2, 3 ] )
), MODULE . '->new( sub {} )' );
is( ref $obj[-1], MODULE, 'ref $object' );

lives_ok( sub{ $obj[1]->do }, '$object->do' );
lives_ok( sub{ $obj[0]->do( sub {} ) }, '$object->do( sub {} )' );
lives_ok( sub{ $obj[0]->do('label1') }, '$object->do("label") run 1' );
lives_ok( sub{ $obj[0]->do('label1') }, '$object->do("label") run 2' );
lives_ok( sub{ $obj[0]->do('label1') }, '$object->do("label") run 3' );

my $history;
lives_ok( sub { $history = $obj[0]->history }, '$object->history' );
is( @$history, 5, 'full history size' );

lives_ok( sub { $history = $obj[0]->history('label1') }, '$object->history("label")' );
is( @$history, 3, 'label history size' );

lives_ok( sub { $history = $obj[0]->history('label1', 2 ) }, '$object->history( "label", 2 )' );
is( @$history, 2, 'label history size' );

ok( $obj[0]->last, '$object->last' );
ok( $obj[0]->last('label1'), '$object->last("label")' );
ok( $obj[0]->last( 'label1', 1138 ), '$object->last( "label", time )' );
is( $obj[0]->last('label1'), 1138, '$object->last("label") # new time' );

ok( $obj[0]->now, '$object->now' );

done_testing;
