package Path::Find::CommandLine::Tradis;

#ABSTRACT: Given a lane id, a study id or a study name, it will return the paths to the tradis data

=head1 NAME

Path::Find::CommandLine::Tradis

=head1 SYNOPSIS

	use Path::Find::CommandLine::Tradis;
	my $pipeline = Path::Find::CommandLine::Tradis->new(
		script_name => 'tradisfind',
		args        => \@ARGV
	)->run;

where \@ARGV contains the following parameters:
-t|type      <study|lane|file|sample|species>
-i|id        <study id|study name|lane name>
-l|symlink   <create a symlink to the data>
-a|arvhive   <archive the data>
-f|filetype  <coverage|intergenic|bam|spreadsheet>
-v|verbose   <extended details>
-r|reference <select only results mapped to given reference>
-d|date      <select only results produced after given date>
-m|mapper    <select only results produced by given mapper>
-h|help      <print help message>

=head1 CONTACT

path-help@sanger.ac.uk

=head1 METHODS

=cut

use Moose;

use Cwd;
use Cwd 'abs_path';
use lib "/software/pathogen/internal/pathdev/vr-codebase/modules"
  ;    #Change accordingly once we have a stable checkout
use lib "../lib";
use lib './lib';

use Getopt::Long qw(GetOptionsFromArray);
use File::Basename;

use Path::Find;
use Path::Find::Lanes;
use Path::Find::Filter;
use Path::Find::Log;
use Path::Find::Sort;
use Path::Find::Exception;

has 'args'         => ( is => 'ro', isa => 'ArrayRef', required => 1 );
has 'script_name'  => ( is => 'ro', isa => 'Str',      required => 1 );
has 'type'         => ( is => 'rw', isa => 'Str',      required => 0 );
has 'id'           => ( is => 'rw', isa => 'Str',      required => 0 );
has 'file_id_type' => ( is => 'rw', isa => 'Str',      required => 0, default => 'lane' );
has 'symlink'      => ( is => 'rw', isa => 'Str',      required => 0 );
has 'archive'      => ( is => 'rw', isa => 'Str',      required => 0 );
has 'help'         => ( is => 'rw', isa => 'Str',      required => 0 );
has 'verbose'      => ( is => 'rw', isa => 'Str',      required => 0 );
has 'filetype'     => ( is => 'rw', isa => 'Str',      required => 0 );
has 'ref'          => ( is => 'rw', isa => 'Str',      required => 0 );
has 'date'         => ( is => 'rw', isa => 'Str',      required => 0 );
has 'mapper'       => ( is => 'rw', isa => 'Str',      required => 0 );
has '_environment' => ( is => 'rw', isa => 'Str',      required => 0, default => 'prod' );

sub BUILD {
    my ($self) = @_;

    my (
        $type,  $id, $file_id_type, $symlink, $archive, $help, $verbose,
        $filetype, $ref,     $date,    $mapper, $test
    );

    my @args = @{ $self->args };
    GetOptionsFromArray(
        \@args,
        't|type=s'      => \$type,
        'i|id=s'        => \$id,
        'file_id_type=s' => \$file_id_type,
        'h|help'        => \$help,
        'f|filetype=s'  => \$filetype,
        'l|symlink:s'   => \$symlink,
        'a|archive:s'   => \$archive,
        'v|verbose'     => \$verbose,
        'r|reference=s' => \$ref,
        'd|date=s'      => \$date,
        'm|mapper=s'    => \$mapper,
        'test'          => \$test,
    );

    $self->type($type)         if ( defined $type );
    $self->id($id)             if ( defined $id );
    $self->file_id_type($file_id_type) if ( defined $file_id_type );
    $self->archive($archive)   if ( defined $archive );
    $self->help($help)         if ( defined $help );
    $self->verbose($verbose)   if ( defined $verbose );
    $self->filetype($filetype) if ( defined $filetype );
    $self->ref($ref)           if ( defined $ref );
    $self->date($date)         if ( defined $date );
    $self->mapper($mapper)     if ( defined $mapper );
    $self->_environment('test') if ( defined $test );

    if ( defined $symlink ){
        if ($symlink eq ''){
            $self->symlink($symlink);
        }
        else{
            $symlink =~ s/\/$//;
            my $ap = abs_path($symlink);
            if ( defined $ap ){ $self->symlink($ap); }
            else { $self->symlink($symlink); }
        }
    }
}

sub check_inputs{
    my $self = shift;
    return(
             $self->type
          && $self->id
          && $self->id ne ''
          && !$self->help
          && ( $self->type eq 'study'
            || $self->type eq 'lane'
            || $self->type eq 'sample'
            || $self->type eq 'file'
            || $self->type eq 'library'
            || $self->type eq 'species'
            || $self->type eq 'database' )
          && ( $self->file_id_type eq 'lane' || $self->file_id_type eq 'sample' )
          && (
            !$self->filetype
            || (
                $self->filetype
                && (   $self->filetype eq 'bam'
                    || $self->filetype eq 'spreadsheet'
                    || $self->filetype eq 'intergenic'
                    || $self->filetype eq 'coverage' )
            )
          )
    );
}

sub run {
    my ($self) = @_;
    $self->check_inputs or Path::Find::Exception::InvalidInput->throw( error => $self->usage_text);

    # assign variables
    my $type     = $self->type;
    my $id       = $self->id;
    my $symlink  = $self->symlink;
    my $archive  = $self->archive;
    my $verbose  = $self->verbose;
    my $filetype = $self->filetype;
    my $ref      = $self->ref;
    my $date     = $self->date;
    my $mapper   = $self->mapper;

    Path::Find::Exception::FileDoesNotExist->throw( error => "File $id does not exist.\n") if( $type eq 'file' && !-e $id );

    my $logfile = $self->_environment eq 'test' ? '/nfs/pathnfs05/log/pathfindlog/test/tradisfind.log' : '/nfs/pathnfs05/log/pathfindlog/tradisfind.log';
    eval {
        Path::Find::Log->new(
            logfile => $logfile,
            args    => $self->args
        )->commandline();
    };

    Path::Find::Exception::InvalidInput->throw( error => "The archive and symlink options cannot be used together\n")
      if ( defined $archive && defined $symlink );

    # set file type extension regular expressions
    my %type_extensions = (
        coverage    => '*insert_site_plot.gz',
        intergenic  => '*tab.gz',
        bam         => '*corrected.bam',
        spreadsheet => '*insertion.csv',
    );

    my ( $lane_filter, $vb );
    my $found = 0;

    # Get databases and loop through them
    my $find = Path::Find->new( environment => $self->_environment );
    my @pathogen_databases = $find->pathogen_databases;
    for my $database (@pathogen_databases) {

        # Connect to database and get info
        my ( $pathtrack, $dbh, $root ) = $find->get_db_info($database);

        my $find_lanes = Path::Find::Lanes->new(
            search_type    => $type,
            search_id      => $id,
            file_id_type   => $self->file_id_type,
            pathtrack      => $pathtrack,
            dbh            => $dbh,
            processed_flag => 512
        );
        my @lanes = @{ $find_lanes->lanes };

        unless (@lanes) {
            $dbh->disconnect();
            next;
        }

        # filter lanes
        my $verbose_info = 0;
        if ( $verbose || $date || $ref || $mapper ){
            #$filetype = "bam";
            $verbose_info = 1;
        }
        $lane_filter = Path::Find::Filter->new(
            lanes           => \@lanes,
            filetype        => $filetype,
            root            => $root,
            pathtrack       => $pathtrack,
            type_extensions => \%type_extensions,
            reference       => $ref,
            mapper          => $mapper,
            date            => $date,
			verbose         => $verbose_info
        );
        my @matching_lanes = $lane_filter->filter;

        my $sorted_ml = Path::Find::Sort->new(lanes => \@matching_lanes)->sort_lanes;
        @matching_lanes = @{ $sorted_ml };

      # Set up to symlink/archive. Check whether default filetype should be used
        my $use_default = 0;
        $use_default = 1 if ( !defined $filetype );
        if ( $lane_filter->found && ( defined $symlink || defined $archive ) ) {
            my $name = $self->set_linker_name;
			
			my $script_name = $self->script_name;
            my %link_names = $self->link_rename_hash( \@matching_lanes );
            eval('use Path::Find::Linker');
            my $linker = Path::Find::Linker->new(
                lanes            => \@matching_lanes,
                name             => $name,
                use_default_type => $use_default,
				script_name      => $script_name,
                rename_links     => \%link_names
            );

            $linker->sym_links if ( defined $symlink );
            $linker->archive   if ( defined $archive );
        }

        if (@matching_lanes) {
            $found = 1;
            if ($verbose) {
                foreach my $ml (@matching_lanes) {
                    my $l = $ml->{path};
                    my $r = $ml->{ref};
                    my $m = $ml->{mapper};
                    my $d = $ml->{date};
                    print "$l\t$r\t$m\t$d\n";
                }
            }
            else {
                foreach my $ml (@matching_lanes) {
                    my $l = $ml->{path};
                    print "$l\n";
                }
            }
        }

        $dbh->disconnect();

        #no need to look in the next database if relevant data has been found
        return 1 if ($found);
    }

    unless ($found) {
        Path::Find::Exception::NoMatches->throw( error => "Could not find lanes or files for input data \n");
    }
}

sub link_rename_hash {
    my ($self, $mlanes) = @_;
    my @matching_lanes = @{ $mlanes };

    my %link_names;
    foreach my $mf (@matching_lanes) {
        my $lane = $mf->{path};
        my @parts = split('/', $lane);
        my $f = pop(@parts);
        my $l = pop(@parts);
        $link_names{$lane} = "$l.$f";
    }
    return %link_names;
}

sub set_linker_name {
    my  ($self) = @_;
    my $archive = $self->archive;
    my $symlink = $self->symlink;
    my $id = $self->id;
    my $script_path = $self->script_name;
    $script_path =~ /([^\/]+$)/;
    my $script_name = $1;

    my $name;
    if ( defined $symlink ) {
        $name = $symlink;
    }
    elsif ( defined $archive ) {
        $name = $archive;
    }

    if( $name eq '' ){
        $id =~ /([^\/]+$)/;
        $name = $script_name . "_" . $1;
    }
    my $cwd = getcwd;
    if($name =~ /^\//){
        return $name;
    }
    else{
        return "$cwd/$name";
    }
}

sub usage_text {
    my ($self) = @_;
    my $script_name = $self->script_name;
    print <<USAGE;
Usage: $script_name
  -t|type          <study|lane|file|library|sample|species>
  -i|id            <study id|study name|lane name|file of IDs>
  --file_id_type   <lane|sample> define ID types contained in file. default = lane
  -l|symlink       <create a symlink to the data>
  -a|arvhive       <archive the data>
  -f|filetype      <coverage|intergenic|bam|spreadsheet>
  -v|verbose       <extended details>
  -r|reference     <select only results mapped to given reference>
  -d|date          <select only results produced after given date>
  -m|mapper        <select only results produced by given mapper>
  -h|help          <print this message>

Given a study or lane this will give you the location of the Tradis results. By default it provides the directory, but by specifiying a 'file_type' 
you can narrow it down to particular 
files within the result set. For a single Tradis experiment you will have:

a BAM file with reads corrected according to the protocol,
a spreadsheet with statistics about insertions on each gene,
insertion site plots for each sequence which can be opened in Artemis,
tab files for each sequence with intergenic regions marked up, which can be opened in Artemis.

USAGE
    exit;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
