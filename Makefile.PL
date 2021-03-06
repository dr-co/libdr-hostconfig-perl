use 5.008008;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME              => 'DR::HostConfig',
    VERSION_FROM      => 'lib/DR/HostConfig.pm', # finds $VERSION
    PREREQ_PM         => {
            'Carp'                          => 0,
            'Mouse'                         => 0,
            'Hash::Merge::Simple'           => 0,
    },
    META_MERGE => {
        resources => {
            homepage   => 'https://github.com/nowtaxi/dr-hostconfig',
            bugtracker => 'https://github.com/nowtaxi/dr-hostconfig/issues',
        }
    },
    ABSTRACT_FROM  => 'lib/DR/HostConfig.pm',
    AUTHOR          => [
        'Dmitry E. Oboukhov <unera@debian.org>,',
        'Roman V. Nikolaev <rshadow@rambler.ru>',
    ],
    LICENSE           => 'perl',
);

# open my $file, '>>', 'Makefile';
# print $file "\n\nTEST_VERBOSE = 1\n";
