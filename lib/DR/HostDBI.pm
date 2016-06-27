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

# Хелперы из импорта
our %HELPERS;

=head1 EXPORTS

=head2 dbh

DBI хендл

=head2 tsqldir

Путь к шаблонам

=cut

our %dbh;

sub dbh {
    $dbh{$$} //= __PACKAGE__->new;
    return $dbh{$$}->handle;
}

sub tsqldir {
    $dbh{$$} //= __PACKAGE__->new;
    return $dbh{$$}->tsql;
}

END {
    if (my $this_host_handle = $dbh{$$}) {
        $this_host_handle->handle->disconnect;
    }
}

=head2 tsql

Путь к шаблонам SQL

=cut

has tsql => is => 'ro', isa => 'Str', default => sub {
    return rel2abs catfile dirname(cfgdir), 'tsql';
};

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

    # Используем форсирование хостнеймов через переменные окружения
    unless ($ENV{USE_HOST_DATABASE}) {
        return $self->tdbi if $ENV{USE_TEST_DATABASE};
    }

    # Переключимся на вывод для тестовой БД если мы в тесте
    return $self->tdbi if $0 =~ /\.t$/;

    # Строка коннектора к БД
    my $str = sprintf "dbi:Pg:dbname=%s;host=%s;port=%s",
        cfg('db.name'),
        cfg('db.host'),
        eval { cfg('db.port') } || 5432;

    # Вернем массив параметров для подключения
    return (
        $str,
        cfg('db.login'),
        cfg('db.password'),
        {
            RaiseError          => 1,
            PrintError          => 0,
            PrintWarn           => 0,
            pg_enable_utf8      => 1,
            dr_sql_dir          => $self->tsql,
            dr_decode_errors    => 1,
            pg_server_prepare   => 0,
        }
    );
}

=head2 tdbi

Возвращает то же самое что и функция L<dbi>, но для тестовой БД

=cut

sub tdbi {
    my ($self) = @_;

    # Строка коннектора к БД
    my $str = sprintf "dbi:Pg:dbname=%s;host=%s;port=%s",
        cfg('tdb.name'),
        cfg('tdb.host'),
        eval { cfg('tdb.port') } || 5432;

    # Вернем массив параметров для подключения
    return (
        $str,
        cfg('tdb.login'),
        cfg('tdb.password'),
        {
            RaiseError          => 1,
            PrintError          => 0,
            PrintWarn           => 0,
            pg_enable_utf8      => 1,
            dr_sql_dir          => $self->tsql,
            dr_decode_errors    => 1,
            pg_server_prepare   => 1,
        }
    );
}

=head2 handle

Возвращает хендл-коннект к БД

=cut

has handle => is => 'ro', isa => 'Object|Undef';

# До использования функции проверяет есть ли активный коннект
before 'handle' => sub {
    my ($self) = @_;

    return if $self->{handle} and $self->{handle}{Active};

    $self->{handle} = DBIx::DR->connect( $self->dbi );

    # Добавим хелперы из импорта
    $self->{handle}->set_helper($_ => $HELPERS{$_}) for keys %HELPERS;
};

=head2 pgstring

Возвращает строку со списком переменных, которые надо установить
для того чтобы сконнектиться с БД

=cut

sub pgstring {
    my ($self) = @_;

    # Используем форсирование хостнеймов через переменные окружения
    unless ($ENV{USE_HOST_DATABASE}) {
        goto \&tpgstring if $ENV{USE_TEST_DATABASE};
    }

    # Переключимся на вывод для тестовой БД если мы в тесте
    goto \&tpgstring if $0 =~ /\.t$/;

    my $str = '';
    $str .= 'PGHOST=' .         cfg 'db.host';
    $str .= ' PGUSER=' .        cfg 'db.login';
    $str .= ' PGPASSWORD=' .    cfg 'db.password';
    $str .= ' PGDATABASE=' .    cfg 'db.name';
    eval { $str .= ' PGPORT=' . cfg 'db.port' };

    print "$str\n";
}

=head2 tpgstring

Возвращает строку со списком переменных, которые надо установить
для того чтобы сконнектиться с тестовой БД

=cut

sub tpgstring {
    my ($self) = @_;

    my $str = '';
    $str .= 'PGHOST=' .         cfg 'tdb.host';
    $str .= ' PGUSER=' .        cfg 'tdb.login';
    $str .= ' PGPASSWORD=' .    cfg 'tdb.password';
    $str .= ' PGDATABASE=' .    cfg 'tdb.name';
    eval { $str .= ' PGPORT=' . cfg 'tdb.port' };

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
