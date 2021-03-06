#!/usr/bin/env perl
use strict;
use warnings;
use File::Slurp;
use File::Path qw( remove_tree);
use Cwd 'abs_path';

BEGIN { unshift( @INC, './lib' ) }
BEGIN { unshift(@INC, '/software/pathogen/internal/pathdev/vr-codebase/modules') }

BEGIN {
    use Test::Most;
}

use_ok('Path::Find::Linker');

my ( @lanes, $linker_obj, $link_dir );

@lanes = (
    { path => 't/data/links' }
);

$link_dir = abs_path('./symlink_test');

ok(
    $linker_obj = Path::Find::Linker->new(
        lanes => \@lanes,
        name  => $link_dir,
	_default_type => '/*.fastq',
	use_default_type => 1
    ),
    'creating linker object'
);

#test symlink creation
#ok( $linker_obj->sym_links, 'testing sym linking' );

#ok( -l "$link_dir/test1.fastq",
#    'checking link existence' );
#ok( -l "$link_dir/test2.fastq",
#    'checking link existence' );
#ok( -l "$link_dir/test3.fastq",
#    'checking link existence' );
#clean up
#remove_tree("$link_dir");

#test archive creation
#ok( $linker_obj->archive, 'testing archive creation' );

#ok( -e "link_test.tar.gz" );

#system("tar xvfz link_test.tar.gz");
#ok( -e "$link_dir/test1.fastq",
#    'checking file existence' );
#ok( -e "$link_dir/test2.fastq",
#    'checking file existence' );
#ok( -e "$link_dir/test3.fastq",
#    'checking file existence' );
#clean up
#remove_tree("link_test");

#test link renaming
#my %link_names = (
#    't/data/links/test1.fastq' => 't1.fastq',
#    't/data/links/test2.fastq' => 't2.fastq',
#    't/data/links/test3.fastq' => 't3.fastq'
#);
#ok(
#    $linker_obj = Path::Find::Linker->new(
#        lanes        => \@lanes,
#        name         => 'link_rename_test',
#        rename_links => \%link_names
#    ),
#    'creating linker object'
#);

#test renamed symlink creation
#ok( $linker_obj->sym_links, 'testing renamed sym linking' );
#ok( -l "link_rename_test/t1.fastq",
#    'checking link existence' );
#ok( -l "link_rename_test/t2.fastq",
#    'checking link existence' );
#ok( -l "link_rename_test/t3.fastq",
#    'checking link existence' );
#clean up
#remove_tree("link_rename_test");

#test archive creation
#ok( $linker_obj->archive, 'testing renamed archive creation' );
#ok( -e "link_rename_test.gz" );

#system("tar xvfz link_rename_test.tar.gz");
#ok( -e "link_rename_test/t1.fastq",
#    'checking file existence' );
#ok( -e "link_rename_test/t2.fastq",
#    'checking file existence' );
#ok( -e "link_rename_test/t3.fastq",
#    'checking file existence' );
#clean up
#remove_tree("link_test");
#remove_tree("link_rename_test");

done_testing();
