package CATS::Problem::Source::PlainFiles;

use strict;
use warnings;

use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use File::Copy::Recursive qw(dircopy);
use File::Glob 'bsd_glob';
use File::Spec;
use File::stat;
use List::Util 'max';

use CATS::BinaryFile;

use base qw(CATS::Problem::Source::Base);

sub new {
    my ($class, %opts) = @_;
    $opts{dir} or die('The directory is not specified');
    bless \%opts => $class;
}

sub open_directory {
    my $self = shift;
    opendir(my $dh, $self->{dir}) or $self->error("Cannot open dir: $!");
    return $dh;
}

sub get_zip {
    my $self = shift;
    my $zip = Archive::Zip->new;
    $zip->addTree($self->{dir}, '', sub { $_ !~ m[/(.git/|.git$)]; });
    open my $fh, '>', \my $content or die "Cannot open filehandle to string: $!";
    my $result = $zip->writeToFileHandle($fh);
    die "Write to filehandle error: $result" unless $result == AZ_OK;
    return $content;
}

sub init { }

sub find_members {
    my ($self, $regexp) = @_;
    {
        my $dh = $self->open_directory;
        return grep /$regexp/, readdir($dh);
    }
}

sub read_member {
    my ($self, $name, $msg) = @_;
    my $fname = File::Spec->catfile($self->{dir}, $name);
    -f $fname or return $msg && $self->error($msg);
    CATS::BinaryFile::load($fname, \my $content);
    return $content;
}

sub finalize {
    # TODO: needed some changes in architecture
    my ($self, $dbh, $repo, $problem, $message, $is_amend, $repo_id, $sha) = @_;

    if (!$problem->{replace}) {
        $repo->init;
        dircopy($self->{dir}, $repo->get_dir);
        $message ||= 'Initial commit';
    }

    $repo->add()->commit($self->{problem}{author}, $message, $is_amend);
}

sub last_modified {
    my ($self) = @_;
    my $dir = $self->{dir};
    my (@path, @folder);
    while ($dir) {
        my @new_path = bsd_glob(File::Spec->catfile($dir, '*'));
        push @path, @new_path;
        -d $_ and push @folder, $_ for @new_path;
        $dir = pop @folder;
    }
    push @path, $self->{dir};
    max(map stat($_)->mtime, @path);
}

1;
