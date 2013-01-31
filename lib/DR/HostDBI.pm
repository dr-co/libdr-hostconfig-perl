use utf8;

package DR::HostDBI;
use Mouse;
extends qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(dbh);

use DBIx::DR;
use DR::HostConfig          qw(cfg cfgdir);
use File::Spec::Functions   qw(catfile rel2abs);
use File::Basename          qw(dirname);

sub dbh {
    our %dbh;
    $dbh{$$} //= __PACKAGE__->new;
    return $dbh{$$}->handle;
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

    # Переключимся на вывод для тестовой БД если стоят переменные окружения
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
};

=head2 pgstring

Возвращает строку со списком переменных, которые надо установить
для того чтобы сконнектиться с БД

=cut

sub pgstring {
    my ($self) = @_;

    unless ($ENV{USE_HOST_DATABASE}) {
        goto \&tpgstring if $ENV{USE_TEST_DATABASE};
    }

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

__PACKAGE__->meta->make_immutable();
1;

=head1 COPYRIGHT

Copyright (C) 2011 Dmitry E. Oboukhov <unera@debian.org>
Copyright (C) 2011 Roman V. Nikolaev <rshadow@rambler.ru>

All rights reserved. If You want to use the code You
MUST have permissions from Dmitry E. Oboukhov AND
Roman V Nikolaev.

=cut
