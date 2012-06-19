package Proc::PidFile::Info;
# ABSTRACT: gather proces info from PID files

use strict;
use warnings;

use constant DEFAULT_LOCATION => '/var/run';
use constant DEFAULT_INFO_LEVEL => 0;
use constant DEFAULT_AUTOSCAN => 1;

use constant STAT_CTIME => 10;

sub new
{
    my $class = shift;
    my %args = @_;

    my $self;

    $self->{locations}  = exists $args{locations}  ? ( ref($args{locations}) eq 'ARRAY' ) ? $args{locations} : [ $args{locations} ] : [ DEFAULT_LOCATION ];
    $self->{info_level} = exists $args{info_level} ? $args{info_level} : DEFAULT_INFO_LEVEL;
    $self->{autoscan}   = exists $args{autoscan}   ? $args{autoscan} : DEFAULT_AUTOSCAN;

    $self->{pidfiles}   = [];

    bless $self, $class;

    $self->scan() if $self->{autoscan};
    return $self;
}


sub info_level { return $_[0]->{info_level} }

sub autoscan { return $_[0]->{autoscan} }

sub location { return wantarray ? @{$_[0]->{pidfiles}}:$_[0]->{locations} }

sub pidfiles { return wantarray ? @{$_[0]->{pidfiles}} : $_[0]->{pidfiles} }

sub scan
{
    my $self = shift;

    my @files;

    foreach my $location (@{$self->{locations}}) {
        if (-d $location and -r $location) {
            push @files, _collect_files( $location );
        }
        elsif (-f $location and -r $location) {
            push @files, $location;
        }
        else {
            # invalid location, skip
        }
    }

    $self->{pidfiles} =  [ $self->_collect_info( @files ) ];

    return 1;
}

sub _collect_files
{
    my $dir = shift;

    opendir(my $dh, $dir) or die "Can not open directory $dir for reading: $!";
    my (@files);
    while(my $entry = readdir($dh)) {
        next if $entry =~ /^\./;
        next unless $entry =~ /\.pid$/;
        my $file = "$dir/$entry";
        next unless -f $file and -r $file;
        push @files, $file;
    }

    return @files;
}

sub _collect_info
{
    my ($self, @files) = @_;

    my @info;

    foreach my $file (@files) {
        my $info = { path => $file };
        if ($file =~ m{([^/]+)\.pid$}) {
            $info->{name} = $1;
        }
        else {
            die "Invalid PID filename: $file";
        }

        if ($self->{info_level} == 0) {         # info level 0 : ctime of pid file
            $info->{ctime} = (stat($file))[STAT_CTIME];
        }
        elsif( $self->{info_level} >= 1) {      # info level 1: ctime + PID
            open( my $fh, '<', $file) or die "Can not open file $file for reading: $!";
            $info->{ctime} = (stat($fh))[STAT_CTIME];
            my $pid = <$fh>;
            close $fh;

            chomp($pid);
            $info->{pid} = $pid;
        }
        else {
            # negative info level - skip
        }
        push @info, $info;
    }

    return @info;
}

1;
__END__

=head1 SYNOPSIS

  use Proc::PidFile::Info;

  my $info = Proc::PidFile::Info->new( locations => [ qw{/var/run /my/own/rundir/} ], info_level => 1 );

  foreach my $pidfile ( $info->pidfiles() ) {
    print "Service $pidfile->{name} running with PID $pidfile->{pid}, started on " . scalar( localtime ( $pidfile->{ctime} ) ) . "\n";
  }

=head1 DESCRIPTION

This module scans a list of PID file locations and/or directories containing PID files (such as C</var/run>) and gathers information
from the PID files it finds. The PID files must have a C<.pid> extension.

The name of the file (with the C<.pid> extension stripped) is assumed to be the name of the service or daemon that created the PID
file. The creation time of the PID file is assumed to be the timestamp when the service or daemon was last (re)started. The module
can also read the PID from the PID file. The information gathered is returned as an array of hashes. Each hash describes the
information for a PID file and it's associated service or daemon.

There are two level of scanning:

=over 4

=item level 0

Scans only file name and creation time. The info hashes will contain only the C<name> and C<ctime> keys.

=item level 1

Also opens each PID file and reads the PID from it. The info hashes will also contain the C<pid> key, in addition to level 0 keys.

=back

=method new

Creates a new PID file scanner objects. Arguments are:

=over 4

=item locations

A list of files and / or directories to scan. Only files with C<.pid> extension are scanned.

=item info_level

How much detail to extract from PID files. On info level 0 the scanner gathers file name and ctime. On info level 1 the scanner reads
the PID from the file in addition to file name and ctime. Default value: 0.

=item autoscan

If true, the scanner will perform a scan right after it is constructed. The C<pidfiles> information is available right away. If false,
you must call C<scan()> to populate the C<pidfiles> information.

=back

=method info_level

Returns the value of the C<info_level> property.

=method autoscan

Returns the value of the C<autoscan> property.

=method locations

Returns the value of the C<locations> property. Depending upon the calling context a list or an array reference is returned.

=method pidfiles

Returns the value of the C<pidfiles> property, i.e. the information gathered from the PID files. If the C<autoscan> property
is set to false, you must call the C<scan()> method to populate the C<pidfiles> property. Depending upon the calling context
a list ot an array reference is returned.

=method scan

Scans all the locations and re-populates the C<pidfiles> property. This is automatically done on object initialization, if the
C<autoscan> property is set to true.
