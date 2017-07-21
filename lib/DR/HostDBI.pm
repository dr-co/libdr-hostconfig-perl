use utf8;

package DR::HostDBI;
use Mouse;
extends qw(Exporter);

our @EXPORT     = qw(dbh);
our @EXPORT_OK  = qw(dbh tsqldir pgstring);

use DBIx::DR;
use DR::HostConfig          qw(cfg cfgdir);
use File::Spec::Functions   qw(catfile rel2abs);
use File::Basename          qw(dirname);

our $TEST_PREFIX            = 't';
our $INTEST;

BEGIN {
    unless (defined $INTEST) {
        $INTEST = 0;
        unless ($ENV{USE_HOST_DATABASE}) {
            $INTEST = 1 if $ENV{USE_TEST_DATABASE};
        }
        $INTEST = 1 if $0 =~ /\.t$/;
    }
}

# Хелперы из импорта
our %HELPERS;

=head1 EXPORTS

=head2 dbh

DBI хендл

=cut

our %dbh;
sub dbh(;$$) {

    my ($cfg_section, $connection) = @_;

    $cfg_section //= 'db';
    $connection //= 'default';

    $dbh{$$} //= {};
    $dbh{$$}{$connection} //= __PACKAGE__->new(section => $cfg_section);
    return $dbh{$$}{$connection}->handle;
}

END {
    if (my $this_host_handle = $dbh{$$}) {
        for (values %$this_host_handle) {
            $_->handle->disconnect;
        }
    }
}


=head2 tsqldir

Путь к шаблонам

=cut

sub tsqldir(;$$) {
    my ($cfg_section, $connection) = @_;
    dbh($cfg_section, $connection)->tsql;
}

=head2 tsql

Путь к шаблонам SQL

=cut

has tsql => is => 'ro', isa => 'Str', default => sub {
    return rel2abs catfile dirname(cfgdir), 'tsql';
};

=head2 section

Секция в конфиг-файле с описанием доступов к БД

=cut

has section => is => 'ro', isa => 'Str', default => 'db';

=head2 dbi

Возвращает массив из четырех элементов:

=over

=item строка конфигурации для DBI

=item логин

=item пароль

=item дефолтные настройки коннектора к постгрис

=back

=cut

sub dbi {
    my ($self) = @_;

    my $section = $self->section;

    $section = $TEST_PREFIX . $section if $INTEST;

    my $cfg = cfg($section);
    for (qw(name host login password)) {
        die "Секция конфига $section.$_ не определена" unless exists $cfg->{$_};
    }

    # Строка коннектора к БД
    my $str = sprintf "dbi:Pg:dbname=%s;host=%s;port=%s",
        $cfg->{name},
        $cfg->{host},
        $cfg->{port} || 5432;

    # Вернем массив параметров для подключения
    return (
        $str,
        $cfg->{login},
        $cfg->{password},
        {
            RaiseError          => 1,
            PrintError          => 0,
            PrintWarn           => 0,
            pg_enable_utf8      => 1,
            dr_sql_dir          => $self->tsql,
            dr_decode_errors    => 1,
            pg_server_prepare   => 0,
            %{ $cfg->{opts} // {} }
        }
    );
}


=head2 handle

Возвращает хендл-коннект к БД

=cut

# До использования функции проверяет есть ли активный коннект
sub handle {
    my ($self) = @_;

    return $self->{handle} if $self->{handle} and $self->{handle}{Active};

    $self->{handle} = DBIx::DR->connect( $self->dbi );

    # Добавим хелперы из импорта
    $self->{handle}->set_helper($_ => $HELPERS{$_}) for keys %HELPERS;
    $self->{handle};
};


=head2 tpgstring

Возвращает строку со списком переменных, которые надо установить
для того чтобы сконнектиться с тестовой БД

=cut

sub tpgstring(;$) {
    my ($section) = @_;

    $section //= 'db';
    $section = $TEST_PREFIX . $section;

    my $str = '';
    $str .= 'PGHOST=' .         cfg "$section.host";
    $str .= ' PGUSER=' .        cfg "$section.login";
    $str .= ' PGPASSWORD=' .    cfg "$section.password";
    $str .= ' PGDATABASE=' .    cfg "$section.name";
    eval { $str .= ' PGPORT=' . cfg "$section.port" };

    print "$str\n";
}

=head2 pgstring

Возвращает строку со списком переменных, которые надо установить
для того чтобы сконнектиться с БД

=cut

sub pgstring(;$) {
    my ($section) = @_;
    $section //= 'db';

    # Переключимся на вывод для тестовой БД если мы в тесте
    goto \&tpgstring if $INTEST;

    my $str = '';
    $str .= 'PGHOST=' .         cfg "$section.host";
    $str .= ' PGUSER=' .        cfg "$section.login";
    $str .= ' PGPASSWORD=' .    cfg "$section.password";
    $str .= ' PGDATABASE=' .    cfg "$section.name";
    eval { $str .= ' PGPORT=' . cfg "$section.port" };

    print "$str\n";
}

=head2 set_helper

Добавляет хелпер в DBIx::DR

=cut

sub set_helper {
    my ($self, $name => $sub) = @_;

    # Добавим в текущий объект если он уже есть
    $self->{handle}->set_helper($name => $sub) if $self->{handle};

    # Добавим в общий список
    $HELPERS{$name} = $sub;

    return 1;
}

sub import {
    my ($package, @args) = @_;

    for (0 .. $#args - 1) {
        if ($args[$_] and $args[$_] eq 'helpers') {
            my ($name, $helpers) = splice @args, $_, 2;
            %HELPERS = (%HELPERS, %$helpers);
            redo;
        }
    }

    $package->export_to_level(1, $package, @args);
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
