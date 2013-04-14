#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use open qw(:std :utf8);
use lib qw(lib ../lib ../../lib);

use Test::More tests    => 15;
use Encode qw(decode encode);
use FindBin;

BEGIN {
    use_ok 'DR::HostConfig', dir => "$FindBin::Bin/test-config";
    use_ok 'DR::HostDBI', 'pgstring', helpers => {
        test    => sub {}
    };
}

my $dbi = DR::HostDBI->new;
ok $dbi, 'Объект создан';

note 'Проверка путей';
ok $dbi->tsql, 'Путь для шаблонов задан';

note 'Проверка конфигурации';
my ($str, $login, $password, $opts) = $dbi->dbi;
ok $str,        'Строка подключения собрана';
is $login,      '111',   'Логин';
is $password,   '222',   'Пороль';

isa_ok $opts, 'HASH', 'Параметры';
ok $opts->{RaiseError},         'Ошибки БД перехватываются';
ok $opts->{pg_enable_utf8},     'UTF8 включен';
ok $opts->{dr_sql_dir},         'Директория шаблонов задана';
ok $opts->{dr_decode_errors},   'Ошибки шаблонов';

ok %DR::HostDBI::HELPERS, 'Хелперы присутствуют';
isa_ok $DR::HostDBI::HELPERS{test}, 'CODE', 'Тестовый хелпер добавлен';
can_ok $dbi, 'set_helper';

#note 'Проверка работы с БД';
#ok $dbi->handle, 'Подключение получено';
#
#my $t1 = $dbi->handle->single(q{SELECT 100500 AS "test"});
#ok $t1,                 'Запрос выполнен';
#ok $t1->test == 100500, 'Получены верные данные';
#
#note 'Проверка экпорта и синглетона';
#ok dbh, 'Подключение получено';
#my $t2 = dbh->single(q{SELECT 500100 AS "test"});
#ok $t2,                 'Запрос выполнен';
#ok $t2->test == 500100, 'Получены верные данные';

=head1 COPYRIGHT

Copyright (C) 2011 Dmitry E. Oboukhov <unera@debian.org>
Copyright (C) 2011 Roman V. Nikolaev <rshadow@rambler.ru>

All rights reserved. If You want to use the code You
MUST have permissions from Dmitry E. Oboukhov AND
Roman V Nikolaev.

=cut
