use utf8;

package DR::HostConfig;
use Mouse;
use namespace::autoclean;
extends qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(cfg);

use Carp;
use Encode                  qw(decode_utf8);
use File::Spec::Functions   qw(catdir catfile);
use File::Basename          qw(dirname fileparse);
use Sys::Hostname           qw(hostname);
use Hash::Merge::Simple;

our $VERSION = '0.02';

=encoding utf-8

=head1 NAME

DR::HostConfig - host configuration loader

The module seeks C<${PROJECT}/config/main.cfg> and then
C<${PROJECT}/config/${HOSTNAME}.cfg> and then load and
merge both files and provide accessors for config records.

All configs have to be in usual Perl format (hashref).

example cfg:
    main.cfg:
        {
            host => '1.2.3.4',
            port => 123,
        }

    myhost.cfg:
        {
            host => '127.0.0.1'
        }

    result cfg:

        {
            host => '127.0.0.1,
            port => 123
        }

If any config is changed the module will reload them.

=head1 SYNOPSIS

  my $cfg = DR::HostConfig->new;
  $cfg->get('path.to.parameter');
  $cfg->set('path.to.parameter' => 111);

=head1 METHODS

=cut

=head2 cfg $path, $value

main accessor. get/set config value.
set isn't write to disk.

    # example config
    {
        a => { b => 'c' }
    }

    my $v = cfg('a');   # returns { b => 'c' }
    my $v = cfg('a.b'); # returns 'c'
    my $v = cfg('abc'); # throws exception

=cut
{

    my $imported_dir;
    my %cfg;
    sub cfg {
        my ($path, $value) = @_;

        $cfg{$$} //= __PACKAGE__->new(
            ($imported_dir ? ( dir => $imported_dir) : () ),
        );

        if( defined $value ) {
            return $cfg{$$}->set($path, $value);
        } else {
            return $cfg{$$}->get($path);
        }
    }

    sub import {
        my ($class, @args) = @_;
        for (reverse 0 .. $#args - 1) {
            next if $args[$_] ne 'dir';
            $imported_dir = $args[$_ + 1];
            splice @args, $_, 2;
            delete $cfg{$$};
        }
        $class->export_to_level(1, $class, @args);
    }

}

=head2 dir

Директория конфигурации

=cut

has 'dir' => ( is => 'ro', isa => 'Str',
    default => sub {
        my ($self) = @_;

        my $dir = File::Spec->rel2abs(
            catdir( dirname(dirname dirname __FILE__), 'config')
        );
        warn "Can't find config directory: $dir\n", unless -d $dir;
        return $dir;
    }
);

=head2 path_main

Путь к основному файлу конфигурации

=cut

has 'path_main' => ( is => 'ro', isa => 'Str',
    default => sub {
        my ($self) = @_;
        my $path = catfile($self->dir, 'main.cfg');
        return $path;
    }
);

=head2 hostname

Хостнейм для хостового файла конфигурации

=cut

has hostname => is => 'rw', isa => 'Str',
    default => sub { $ENV{HOSTNAME} || hostname };

=head2 path_host

Путь к хостовому файлу конфигурации

=cut

has 'path_host' => ( is => 'ro', isa => 'Str',
    default => sub {
        my ($self) = @_;
        my $path = catfile($self->dir, $self->hostname . '.cfg');
        return $path;
    }
);

=head2 utime_main

Время последнего обновления основного конфига

=cut

has 'utime_main' => (is => 'rw', isa => 'Int',
    default => sub {
        my ($self) = @_;
        return $self->get_utime_main;
    }
);

=head2 utime_host

Время последнего обновления хостового конфига

=cut

has 'utime_host' => (is => 'rw', isa => 'Int',
    default => sub {
        my ($self) = @_;
        return $self->get_utime_host;
    }
);

=head2 data

Собственно конфигурация.

=cut

has 'data' => (is => 'ro', isa => 'HashRef', default => sub{
    my ($self) = @_;
    $self->load_main and $self->load_host and $self->merge
            or warn 'Can not merge/reload configuration';
    return $self->{data};
});

# Проверка и обновление конфигурации
before 'data' => sub {
    my ($self) = @_;

    # Проверим что требуется проверка изменения конфига
    return unless $self->check_need_update;

    # Обновление конфига если он устарел
    if($self->is_changed_main or $self->is_changed_host) {
        $self->load_main and $self->load_host and $self->merge
            or warn 'Can not merge/reload configuration';
    }
    return;
};

=head2 load_main

Загрузка основного файла конфигурации

=cut

sub load_main {
    my ($self) = @_;

    return 1 unless $self->path_main;

    # Получим конфигурацию из файла
    my $cfg = -r $self->path_main ? do $self->path_main : {};

    if ($@) {
        warn "Error parse main.cfg: " . decode_utf8 $@;
        $self->{_main} = {};
        return 0;
    }
    unless('HASH' eq ref $cfg) {
        warn "main.cfg doesn't contain HASHREF";
        $self->{_main} = {};
        return 0;
    }

    # Сохраним полученную конфигурацию
    $self->{_main} = $cfg;

    return 1;
}

=head2 load_host

Загрузка хостового файла конфигурации

=cut

sub load_host {
    my ($self) = @_;

    return 1 unless $self->path_host;

    # Получим конфигурацию из файла
    my $cfg = -r $self->path_host ? do $self->path_host : {};
    if ($@) {
        warn "Error parse " . $self->path_host . " : " . decode_utf8 $@;
        $self->{_host} = {};
        return 0;
    }
    unless('HASH' eq ref $cfg) {
        warn $self->path_host . " doesn't contain HASHREF";
        $self->{_host} = {};
        return 0;
    }

    # Сохраним полученную конфигурацию
    $self->{_host} = $cfg;

    return 1;
}

=head2 merge

Объединение загруженной основной и хостовой конфигураций

=cut

sub merge {
    my ($self) = @_;

    # Объединим конфигурации

    $self->{data} //= {};
    my $data = eval {
        Hash::Merge::Simple::merge $self->{_main}, $self->{_host};
    };
    if( $@ ) {
        warn "Can't merge configs: " . decode_utf8 $@;
        return 0;
    }

    delete $self->{_main};
    delete $self->{_host};
    $self->{data} = $data;
    $self->{cache} = {};

    return 1;
}


=head2 get $path

Получение параметра по его пути

=cut

sub get {
    my ($self, $path) = @_;

    croak 'path was not defined' unless $path;
    return $self->{cache}{$path} if exists $self->{cache}{$path};

    # Сплитим по любым левым символам
    my @keys = split m{[^\w+]}, $path;

    my $param = $self->data;
    my $cpath = '';

    for my $key (@keys) {
        $cpath .= '=>' if length $cpath;
        $cpath = $key;
        unless('HASH' eq ref $param) {
            croak "Error config format ('$cpath')";
            return;
        }
        unless(exists $param->{$key}) {
            croak "$cpath not found in config";
            return;
        }
        $param = $param->{$key};
    }

    return $self->{cache}{$path} = $param;
}

=head2 set $path

Установка параметра по его пути

=cut

sub set {
    my ($self, $path, $value) = @_;

    croak 'path was not defined' unless $path;
    croak 'valuse was not defined' unless @_ > 2;

    # Сплитим по любым левым символам
    my @keys = split m{[^\w+]}, $path;
    my $last = pop @keys;

    my $param = $self->data;
    my $cpath = '';

    for my $key (@keys) {
        $cpath .= '=>' if length $cpath;
        $cpath = $key;
        unless('HASH' eq ref $param) {
            croak "Error config format ('$cpath')";
            return;
        }
        unless(exists $param->{$key}) {
            croak "$cpath not found in config";
            return;
        }
        $param = $param->{$key};
    }

    my $old = $param->{$last};
    $param->{$last} = $value;

    return $self->{cache}{$path} = $value;
}

=head2 get_utime_main

Получение времени последнего обновления основного файла конфигурации

=cut

sub get_utime_main {
    my ($self) = @_;
    return 0 unless $self->path_main;
    return 0 unless -r $self->path_main;
    return (stat $self->path_main )[10]
}

=head2 get_utime_host

Получение времени последнего обновления хостового файла конфигурации

=cut

sub get_utime_host {
    my ($self) = @_;
    return 0 unless -f $self->path_host;
    return (stat $self->path_host )[10];
}

=head2 is_changed_main

Проверка изменения основного файла конфигурации

=cut

sub is_changed_main {
    my ($self) = @_;
    my $old = $self->utime_main;
    my $new = $self->get_utime_main;

    if( $new > $old ) {
        $self->utime_main($new);
        return 1;
    }

    return 0;
}

=head2 is_changed_main

Проверка изменения хостового файла конфигурации

=cut

sub is_changed_host {
    my ($self) = @_;

    return 0 unless $self->path_host;

    my $old = $self->utime_host;
    my $new = $self->get_utime_host;

    if( $new > $old ) {
        $self->utime_host($new);
        return 1;
    }

    return 0;
}

# Время последней проверки на обновление
has last_update_time => is => 'rw', isa => 'Int', default => sub{ time };
# Таймаут для проверки на обновление
has update_timeout   => is => 'rw', isa => 'Int', default => 10;

=head2 check_need_update

Проверка на необходимость проверки изменения файла конфигурации.

=cut

sub check_need_update {
    my ($self) = @_;
    my $time = time;
    # Проверяем раз в секунду
    if( $time >= $self->last_update_time + $self->update_timeout) {
        $self->last_update_time( $time );
        return 1;
    }
    return 0;
}

__PACKAGE__->meta->make_immutable();
1;

=head1 COPYRIGHT

Copyright (C) 2011 Dmitry E. Oboukhov <unera@debian.org>
Copyright (C) 2011 Roman V. Nikolaev <rshadow@rambler.ru>

All rights reserved. If You want to use the code You
MUST have permissions from Dmitry E. Oboukhov AND
Roman V Nikolaev.

=cut
