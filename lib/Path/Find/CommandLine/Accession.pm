package Path::Find::CommandLine::Accession;

=head1 NAME

accessionfind

=head1 SYNOPSIS

Sample usage:
perl accessionfind --lanes=/nfs/users/nfs_a/ap12/tmp/rt_224699/lanes_2.list -db=prok

=head1 DESCRIPTION

Looks up the accession number (ERR...) for each of the lanes specified in the input file (lanes.list)

=head1 CONTACT

pathdevg@sanger.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;
no warnings 'uninitialized';

use lib "/software/pathogen/internal/pathdev/vr-codebase/modules"
  ;    #Change accordingly once we have a stable checkout
use lib "/software/pathogen/internal/prod/lib";
use lib "../lib";

use Getopt::Long qw(GetOptionsFromArray);
use WWW::Mechanize;

use Path::Find;
use Path::Find::Lanes;
use Path::Find::Log;

has 'args'        => ( is => 'ro', isa => 'ArrayRef', required => 1 );
has 'script_name' => ( is => 'ro', isa => 'Str',      required => 1 );
has 'type'        => ( is => 'rw', isa => 'Str',      required => 0 );
has 'id'          => ( is => 'rw', isa => 'Str',      required => 0 );
has 'help'        => ( is => 'rw', isa => 'Str',      required => 0 );
has 'external'    => ( is => 'rw', isa => 'Str',      required => 0 );
has 'submitted'   => ( is => 'rw', isa => 'Str',      required => 0 );
has 'outfile' =>
  ( is => 'rw', isa => 'Str', required => 0, default => 'accessionfind.out' );
has 'help' => ( is => 'rw', isa => 'Bool', required => 0 );

sub BUILD {
	my ($self) = @_;
	
    $ENV{'http_proxy'} = 'http://webcache.sanger.ac.uk:3128/';

    my ( $type, $id, $help, $external, $submitted, $outfile );

    GetOptionsFromArray(
        $self->args,
        't|type=s'    => \$type,
        'i|id=s'      => \$id,
        'h|help'      => \$help,
        'f|fastq'     => \$external,
        's|submitted' => \$submitted,
        'o|outfile=s' => \$outfile,
    );

    $self->type($type)           if ( defined $type );
    $self->id($id)               if ( defined $id );
    $self->help($help)           if ( defined $help );
    $self->external($external)   if ( defined $external );
    $self->submitted($submitted) if ( defined $submitted );
    $self->outfile($outfile)     if ( defined $outfile );

    # print usage text if required parameters are not present
    (
        $type
          && ( $type eq 'study'
            || $type eq 'lane'
            || $type eq 'file'
            || $type eq 'sample'
            || $type eq 'species'
            || $type eq 'database' )
          && $id
          && !$help
    ) or die $self->usage_text;
}

sub run {
	my ($self) = @_;
	my $type = $self->type;
	my $id = $self->id;
	my $qc = $self->qc;
	my $filetype = $self->filetype;
	my $archive = $self->archive;
	my $stats = $self->stats;
	my $symlink = $self->symlink;
	my $output = $self->output;
	
	eval {
	    Path::Find::Log->new(
	        logfile => '/nfs/pathnfs05/log/pathfindlog/accessionfind.log',
	        args    => $self->args
	    )->commandline();
	};

    # Get databases
    my @pathogen_databases = Path::Find->pathogen_databases;
    my $lanes_found        = 0;

    for my $database (@pathogen_databases) {
        my ( $pathtrack, $dbh, $root ) = Path::Find->get_db_info($database);

        my $find_lanes = Path::Find::Lanes->new(
            search_type    => $type,
            search_id      => $id,
            pathtrack      => $pathtrack,
            dbh            => $dbh,
            processed_flag => 0
        );
        my @lanes = @{ $find_lanes->lanes };

        unless (@lanes) {
            $dbh->disconnect();
            next;
        }
        for my $lane (@lanes) {

            # get sample and lane accessions
            my $sample = $self->get_sample_from_lane( $pathtrack, $lane );
            my $sample_name = $sample->name            if defined $sample;
            my $sample_acc  = $sample->individual->acc if defined $sample;
            my $lane_acc    = $lane->acc;
            $sample_name = 'not found' unless defined $sample_name;
            $sample_acc  = 'not found' unless defined $sample_acc;
            $lane_acc    = 'not found' unless defined $lane_acc;

            # print sample and lane accessions
            print join( "\t",
                ( $sample_name, $sample_acc, $lane->name, $lane_acc ) )
              . "\n";

            # output url
            if ( ( $lane->acc ) && ($external) ) {
                $self->print_ftp_url( "dl", $lane->acc, $outfile );
            }
            if ( ( $lane->acc ) && ($submitted) ) {
                $self->print_ftp_url( "sub", $lane->acc, $outfile );
            }
        }
        $lanes_found = scalar @lanes;
        last if $lanes_found;    # Stop looking if lanes found.
    }

    # No lanes found
    print "No lanes found for search of '$type' with '$id'\n"
      unless $lanes_found;
}

sub print_ftp_url {
    my $url_type = shift;
    my $acc      = shift;
    my $outfile  = shift;
    open( OUT, ">> $outfile" );
    my $url;
    if ( $url_type eq "sub" ) {
        $url =
          'http://www.ebi.ac.uk/ena/data/view/reports/sra/submitted_files/';
    }
    else {
        $url = 'http://www.ebi.ac.uk/ena/data/view/reports/sra/fastq_files/';
    }
    $url .= $acc;
    my $mech = WWW::Mechanize->new;
    $mech->get($url);
    my $down = $mech->content( format => 'text' );
    my @lines = split( /\n/, $down );
    foreach my $x ( 1 .. $#lines ) {
        my @fields = split( /\t/, $lines[$x] );
        print OUT "$fields[18]\n";
    }
}

sub get_sample_from_lane {
    my ( $vrtrack, $lane ) = @_;
    my ( $library, $sample );

    $library = VRTrack::Library->new( $vrtrack, $lane->library_id );
    $sample = VRTrack::Sample->new( $vrtrack, $library->sample_id )
      if defined $library;

    return $sample;
}

sub usage_text {
    my ($self) = @_;
    my $scriptname = $self->script_name;
    print <<USAGE;
Usage: $scriptname -t <type> -i <id> [options]   
	 t|type      <study|lane|file|sample|species>
	 i|id        <study id|study name|lane name|file of lane names|lane accession|sample accession>
	 f|fastq     <generate ftp addresses for fastq file download from ENA>
	 s|submitted <generate ftp addresses for submitted file download. Format varies>
	 o|outfile   <file to write output to. If not given, defaults to accessionfind.out>
	 h|help      <this message>
USAGE
    exit;
}
