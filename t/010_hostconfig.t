#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use open qw(:std :utf8);
use lib qw(lib ../../lib);

use Test::More tests    => 28;
use Encode qw(decode encode);
use FindBin;

BEGIN {
    # Подготовка объекта тестирования для работы с utf8
    my $builder = Test::More->builder;
    binmode $builder->output,         ":utf8";
    binmode $builder->failure_output, ":utf8";
    binmode $builder->todo_output,    ":utf8";

    note "************* Тест модуля конфигурации *************";
    use_ok 'DR::HostConfig';
}

my $config;
{
    my $warns = 0;
    local $SIG{__WARN__} = sub { $warns++; };
    $config = DR::HostConfig->new;
    is $warns, 1, 'Одно предупреждение';
}
ok $config, 'Объект создан';

note 'Проверка путей';
ok $config->dir,        'Директория конфигурации: ' . $config->dir;
ok $config->path_main,  'Файл основной:' . $config->path_main;
ok $config->hostname,   'Имя хоста получено';
ok $config->path_host,  'Файл хостовый: ' . ($config->path_host || 'НЕТ');

note 'Время обновления';

is $config->utime_main, 0, 'Для ненайденного конфига время обновления 0';
is $config->utime_host, 0, 'Для ненайденного хостконфига время тоже 0';

$ENV{HOSTNAME} = 'test';
$config = DR::HostConfig->new(dir => "$FindBin::Bin/test-config");

ok $config->utime_main, 'Время последнего обновления основного файла';
ok $config->utime_host, 'Время последнего обновления хостового файла';

note 'Загрузка файлов конфигурации';
isa_ok $config->data, 'HASH', 'Хеш конфигурации';

ok $config->load_main, 'Загрузка основного файла';
isa_ok $config->{_main},  'HASH', 'Временный хеш основной конфигурации';
ok %{ $config->{_main} }, 'Временный хеш основной конфигурации не пуст';

ok $config->load_host, 'Загрузка хостового файла';
isa_ok $config->{_host},  'HASH', 'Временный хеш хостовой конфигурации';
ok %{ $config->{_host} }, 'Временный хеш хостовой конфигурации не пуст';

ok $config->merge, 'Объединение и обновление конфигов выполнено';
isa_ok $config->data, 'HASH', 'Хеш конфигурации';
ok %{ $config->data }, 'Конфигурация не пуста';

ok !$config->{_main}, 'Временные данные основного конфига удалены';
ok !$config->{_host}, 'Временные данные хостового конфига удалены';

note 'Получение параметров';
eval { $config->get(); };
ok $@, 'Пустой параметр не приемлем';

SKIP: {
    skip 'Конфигурация пуста', 1 unless %{ $config->data };

    my @keys = keys $config->data;
    my $key = shift @keys;
    ok $config->get( $key ), "Параметр '$key' получен";
}

note 'Изменение параметров';
SKIP: {
    skip 'Конфигурация пуста', 2 unless %{ $config->data };

    my @keys = keys $config->data;
    my $key = shift @keys;
    my $old = $config->get( $key );
    ok $old, "Параметр '$key' получен";

    $config->set( $key => $old . '_SOMETHING_ELSE_' );
    my $new = $config->get( $key );
    ok $new eq $old . '_SOMETHING_ELSE_', "Параметр '$key' изменен";
}

note 'Проверка экпорта и синглетона';
SKIP: {
    skip 'Конфигурация пуста', 1 unless %{ $config->data };

    my @keys = keys $config->data;
    my $key = shift @keys;
    DR::HostConfig->import(dir => "$FindBin::Bin/test-config");
    ok cfg( $key ), "Параметр '$key' получен";
}

=head1 COPYRIGHT

Copyright (C) 2011 Dmitry E. Oboukhov <unera@debian.org>
Copyright (C) 2011 Roman V. Nikolaev <rshadow@rambler.ru>

All rights reserved. If You want to use the code You
MUST have permissions from Dmitry E. Oboukhov AND
Roman V Nikolaev.

=cut
