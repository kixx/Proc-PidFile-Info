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
