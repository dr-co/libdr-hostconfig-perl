#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use open qw(:std :utf8);
use lib qw(lib ../../lib);

use Test::More tests    => 63;
use Encode qw(decode encode);
use FindBin;
use experimental 'smartmatch';

BEGIN {
    use_ok 'DR::HostConfig';
}

note 'Проверка путей';
{
    my $config = DR::HostConfig->new(dir => '.');
    ok $config, 'Объект создан';

    ok $config->dir,        'Директория конфигурации: ' . $config->dir;
    ok $config->path_main,  'Файл основной:' . $config->path_main;
    ok $config->hostname,   'Имя хоста получено';
    ok $config->path_host,  'Файл хостовый: ' . ($config->path_host || 'НЕТ');
}

note 'Время обновления';
{
    my $config = DR::HostConfig->new(dir => '.');
    ok $config, 'Объект создан';

    is $config->utime_main, 0, 'Для ненайденного конфига время обновления 0';
    is $config->utime_host, 0, 'Для ненайденного хостконфига время тоже 0';
}

note 'Основной и хостовый конфиги';
{
    $ENV{HOSTNAME} = 'test';
    my $config = DR::HostConfig->new(dir => "$FindBin::Bin/test-config");
    isa_ok $config->data => 'HASH', 'data';

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
}

note 'Основной и хостовый и by-dir конфиги';
{
    $ENV{HOSTNAME} = 'test';
    my $config = DR::HostConfig->new(
        dir         => "$FindBin::Bin/test-config",
        project_dir => "$FindBin::Bin"
    );

    isa_ok $config->data => 'HASH', 'data';

    ok $config->utime_main, 'Время последнего обновления основного файла';
    ok $config->utime_host, 'Время последнего обновления хостового файла';
    ok $config->utime_project, 'Время последнего обновления проектного файла';

    note 'Загрузка файлов конфигурации';
    isa_ok $config->data, 'HASH', 'Хеш конфигурации';

    ok $config->load_main, 'Загрузка основного файла';
    isa_ok $config->{_main},  'HASH', 'Временный хеш основной конфигурации';
    ok %{ $config->{_main} }, 'Временный хеш основной конфигурации не пуст';

    ok $config->load_host, 'Загрузка хостового файла';
    isa_ok $config->{_host},  'HASH', 'Временный хеш хостовой конфигурации';
    ok %{ $config->{_host} }, 'Временный хеш хостовой конфигурации не пуст';
    
    ok $config->load_project, 'Загрузка проектного файла';
    isa_ok $config->{_project},  'HASH', 'Временный хеш проектной конфигурации';
    ok %{ $config->{_project} }, 'Временный хеш проектной конфигурации не пуст';

    ok $config->merge, 'Объединение и обновление конфигов выполнено';
    isa_ok $config->data, 'HASH', 'Хеш конфигурации';
    ok %{ $config->data }, 'Конфигурация не пуста';

    ok !$config->{_main}, 'Временные данные основного конфига удалены';
    ok !$config->{_host}, 'Временные данные хостового конфига удалены';
    ok !$config->{_project}, 'Временные данные проектного конфига удалены';
}

note 'Получение параметров';
{
    my $config = DR::HostConfig->new(dir => "$FindBin::Bin/test-config");
    ok $config, 'Объект создан';

    eval { $config->get(); };
    ok $@, 'Пустой параметр не приемлем';

    SKIP: {
        skip 'Конфигурация пуста', 2 unless %{ $config->data };

        my @keys = keys %{ $config->data };
        my $key = shift @keys;
        ok $config->get( $key ), "Параметр '$key' получен";
        is $config->utime_project, 0, 'Проектный конфиг не в игре';
        is $config->get('c'), 'd', 'Параметр "c" взят из тест конфига';
    }
}
note 'Получение параметров с учетом проектного конфига';
{
    my $config = DR::HostConfig->new(
        dir => "$FindBin::Bin/test-config",
        project_dir => "$FindBin::Bin"
    );
    ok $config, 'Объект создан';

    eval { $config->get(); };
    ok $@, 'Пустой параметр не приемлем';

    SKIP: {
        skip 'Конфигурация пуста', 3 unless %{ $config->data };

        my @keys = keys %{ $config->data };
        my $key = shift @keys;
        ok $config->get( $key ), "Параметр '$key' получен";
        isnt $config->utime_project, 0, 'Проектный конфиг в игре';
        is $config->get('c'), '3', 'Параметр "c" взят из проектного конфига';
    }
}

note 'Изменение параметров';
{
    my $config = DR::HostConfig->new(dir => "$FindBin::Bin/test-config");
    ok $config, 'Объект создан';

    SKIP: {
        skip 'Конфигурация пуста', 2 unless %{ $config->data };

        my @keys = keys %{ $config->data };
        my $key = shift @keys;
        my $old = $config->get( $key );
        ok $old, "Параметр '$key' получен";

        $config->set( $key => $old . '_SOMETHING_ELSE_' );
        my $new = $config->get( $key );
        ok $new eq $old . '_SOMETHING_ELSE_', "Параметр '$key' изменен";
    }
}

note 'Отсутсвие файлов';
{
    my $config = DR::HostConfig->new(dir => 'unknown');
    is eval{ $config->get('a'); 1 }, undef, 'Исключение на получение параметра';
    is eval{ $config->set('a' => 'b'); 1 }, 1,
        'Устанавливать параметры можно';
}

note 'Переопределение hostname';
{
    $ENV{HOSTNAME} = 'test';
    my $config = DR::HostConfig->new(dir => "$FindBin::Bin/test-config");
    ok $config, 'Объект создан';

    is $config->get('c'), 'd', 'Параметр из test';

    ok $config->hostname('another'), 'Переопредилили на another';

    is $config->get('c'), 'e', 'Параметр из another';
}

=head1 COPYRIGHT

Copyright (C) 2011 Dmitry E. Oboukhov <unera@debian.org>
Copyright (C) 2011 Roman V. Nikolaev <rshadow@rambler.ru>

All rights reserved. If You want to use the code You
MUST have permissions from Dmitry E. Oboukhov AND
Roman V Nikolaev.

=cut
