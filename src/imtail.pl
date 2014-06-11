=head1 NAME

imtail -- instant multi-file tail

=head1 SYNOPSYS

imtail <options>

=head1 OPTIONS

=over 4

=item -c <basename_or_file>

config file, which should be written in TOML defined in L<https://github.com/mojombo/toml>.

if not specified, C<imtail> searches file, C<$PWD/.imtail.toml> or C<$HOME/.imtail.toml>, automatically.

search priority is as following:

  * $HOME/.imtail.d/${basename_or_file}.toml
  * $basename_or_file
  * $PWD/.imtail.toml
  * $HOME/.imtail.toml

=item -n <number>

shows <number> lines.

=item -h | --help

shows this usage.

=back

=head1 ENVIRONMENT VARIABLES

=over 4

=item IMTAIL_PERL

specifies perl command. "/usr/bin/env perl" as default.

=item  IMTAIL_SSH

specifies ssh command. "/usr/bin/env ssh" as default.

=back

=head1 CONFIG FILE

should be written in C<TOML>, defined in L<https://github.com/mojombo/toml>.

  # optional: you can use SSH
  ssh = "you@yourhost"

  # files you want to TAIL
  files = [
    "/path/to/yourapp1/var/log/access_log",
    "/path/to/yourapp1/var/log/error_log",
    "/path/to/yourapp2/var/log/error_log",
  ]

=cut

use strict;
use warnings;
use Getopt::Long qw/:config posix_default no_ignore_case gnu_compat/;
use Pod::Usage;
use TOML qw/from_toml/;

my %opts = (
    pwd       => undef,
    basedir   => undef,
    conf_file => undef,
    n         => 10,
    help      => 0,
);
GetOptions(
    'pwd=s'     => \$opts{pwd},
    'basedir=s' => \$opts{basedir},
    'c=s'       => \$opts{conf_file},
    'n=i'       => \$opts{n},
    'h|help'    => \$opts{help},
) or usage();
usage()  if $opts{help};

sub p { print STDERR @_ }

sub usage {
    p "\n";
    pod2usage(
        -exitval   => -1,
        -verbose   => 2,
        -noperldoc => 1,
        -output    => \*STDERR,
    );
}

sub validate {
    my %args = @_;
    my $show_usage = 0;
    my $conf_file = $args{conf_file};
    my $conf_file_default = '.imtail.toml';

    my @search_target;
    if ( defined $conf_file ) {
        push @search_target, (
            "$ENV{HOME}/.imtail.d/${conf_file}.toml",
            ${conf_file},
        );
    }
    push @search_target, (
        "$args{pwd}/${conf_file_default}",
        "$ENV{HOME}/${conf_file_default}",
    );

    ($conf_file) = grep -f , @search_target;
    if ( defined $conf_file ) {
        $args{conf_file} = $conf_file;
    }
    else {
        warn 'config file is not specified or does not exist';
        $show_usage = 1;
    }

    usage()  if $show_usage;
    return %args;
}

sub main {
    my %args = validate( %opts );

    ### config file
    p "config file:\n";
    p "  $args{conf_file}\n";

    my $toml = do {
        local $/;
        open my $fh, '<', $args{conf_file};
        <$fh>;
    };
    my ($data, $error) = from_toml( $toml );
    unless ( $data ) {
        die "config error: $error";
    }

    my $out;
    my ($ssh, @files) = (
        $data->{ssh} || '',
        @{ $data->{files} || [] },
    );

    ### ssh
    if ( $ssh ) {
        p "ssh:\n";
        p "  ${ssh}\n";
        $out .= "$ENV{IMTAIL_SSH} $ssh -- "  if $ssh;
    }

    ### files
    p "files:\n";
    p "  * $_\n" for @files;
    $out .= "tail -Fn$args{n} @files";

    print STDOUT $out;  # pass to shellscript
    return 0;
}

exit main();
