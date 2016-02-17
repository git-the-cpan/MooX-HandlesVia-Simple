use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoTabs 0.15

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'lib/MooX/HandlesVia/Simple.pm',
    't/00-compile.t',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/handlesvia_in_role.t',
    't/hash.t',
    't/invalid.t',
    't/nonmoo-class.t'
);

notabs_ok($_) foreach @files;
done_testing;
