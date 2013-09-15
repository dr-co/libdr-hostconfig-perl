#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use open qw(:std :utf8);
use lib qw(lib ../lib ../../lib);

use Test::More tests    => 5;
use Encode qw(decode encode);
use FindBin;
use experimental 'smartmatch';

my $dir;

BEGIN {
    use_ok 'DR::HostConfig',
        hostname    => 'test',
        dir         => $dir = "$FindBin::Bin/test-config";
}

can_ok 'main', 'cfg';
is cfg('c'), 'd',           'test config used';

is cfg('c' => 'e'), 'e',    'Set';
is cfg('c'),        'e',    'Get updated';

=head1 COPYRIGHT

Copyright (C) 2011 Dmitry E. Oboukhov <unera@debian.org>
Copyright (C) 2011 Roman V. Nikolaev <rshadow@rambler.ru>

All rights reserved. If You want to use the code You
MUST have permissions from Dmitry E. Oboukhov AND
Roman V Nikolaev.

=cut
