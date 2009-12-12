#!/usr/bin/perl
use strict;
use warnings;
use Path::Class qw/dir/;
use LWP::UserAgent;
use Email::Send::Gmail;
use Email::MIME;
use Email::Send;
use Config::Pit qw/pit_get/;
use File::Basename qw/basename/;

die "Usage: $0 targetdir" unless @ARGV;

my $config = pit_get(
    "gmail.com",
    require => {
        "email"    => "your email",
        "password" => "your password"
    }
);

&main;exit;

sub main {
    my $ret = aggregate();
    if ($ret) {
        send_mail($ret);
    }
}

sub aggregate {
    my $res;
    for my $dir (@ARGV) {
        for my $subdir (dir($dir)->children) {
            next unless -d $subdir;
            next unless -d $subdir->subdir(".git");
            chdir $subdir;
            my $status = `git status 2> /dev/null`;
            if ($status =~ /(Your branch is ahead of .+\.)/) {
                $res .= "- ".basename($subdir)."\n$1\n";
            }
        }
    }
    $res;
}

sub send_mail {
    my $body = shift;
    my $email = Email::Simple->create(
        header => [
            From    => $config->{email},
            To      => $config->{email},
            Subject => 'git-push-reminder',
        ],
        body => $body,
    );

    my $sender = Email::Send->new(
        {
            mailer      => 'Gmail',
            mailer_args => [
                username => $config->{email},
                password => $config->{password},
            ]
        }
    );
    eval { $sender->send($email) };
    die "Error sending email: $@" if $@;
}
