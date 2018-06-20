#!/usr/bin/perl -w

# Author          : Johan Vromans
# Created On      : Sat Jun 16 20:58:47 2018
# Last Modified By: Johan Vromans
# Last Modified On: Wed Jun 20 10:18:50 2018
# Update Count    : 192
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use utf8;

# Package name.
my $my_package = 'Sciurix';
# Program name and version.
my ($my_name, $my_version) = qw( vdirfloat 0.01 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $verbose = 1;		# verbose processing
my $action = 0;			# 0 = shift, 1 = make float, -1 unfloat
my $rewrite = 1;		# rewrite the .ics file

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

# Process command line options.
app_options();

# Post-processing.
$trace |= ($debug || $test);

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';
#my $floatsym = "\x{219b}";	# RIGHTWARDS ARROW WITH STROKE
my $floatsym = "\x{21aa}";	# RIGHTWARDS ARROW WITH HOOK

################ The Process ################

use Data::ICal;
use Data::ICal::DateTime;

my $today = DateTime->today( time_zone => "local" );

if ( $action > 0 ) {
    make_float($_) foreach @ARGV;
}
elsif ( $action < 0 ) {
    make_unfloat($_) foreach @ARGV;
}
else {
    foreach ( @ARGV ) {
	if ( -d $_ ) {
	    dir_float($_);
	}
	else {
	    shift_float($_);
	}
    }
}

sub make_float {
    my ( $file ) = @_;

    my $c = fetch($file);
    my $rewrite;

    foreach my $e ( @{ $c->entries } ) {
	next unless $e->ical_entry_type eq 'VEVENT';

	if ( $e->status && $e->status eq "CONFIRMED" ) {
	    warn("$file: Already completed\n") if $verbose;
	    next;
	}

	if ( substr( $e->summary, 0, 1 ) eq $floatsym ) {
	    warn("$file: Already floating\n") if $verbose;
	    next;
	}

	$e->summary( $floatsym . $e->summary );
	last_modified($e);
	$rewrite++;
    }

    rewrite( $c, $file ) if $rewrite;
}

sub make_unfloat {
    my ( $file ) = @_;

    my $c = fetch($file);
    my $rewrite;

    foreach my $e ( @{ $c->entries } ) {
	next unless $e->ical_entry_type eq 'VEVENT';

	unless ( $e->summary =~ /^$floatsym(.*)/s ) {
	    warn("$file: Not floating\n") if $verbose;
	    next;
	}

	$e->summary($1);
	last_modified($e);
	$rewrite++;
    }

    rewrite( $c, $file ) if $rewrite;
}

sub shift_float {
    my ( $file, $c ) = @_;
    $c ||= fetch($file);
    my $rewrite;

    foreach my $e ( @{ $c->entries } ) {
	next unless $e->ical_entry_type eq 'VEVENT';

	unless ( substr( $e->summary, 0, 1 ) eq $floatsym ) {
	    warn("$file: Not floating\n") if $verbose;
	    next;
	}

	if ( $e->status && $e->status eq "CONFIRMED" ) {
	    $e->summary( substr( $e->summary, 1 ) );
	    last_modified($e);
	    $rewrite++;
	    next;
	}

	if ( $e->start->date lt $today->date ) {

	    my $delta = $today->delta_days($e->start);
	    if ( ( $e->properties->{dtstart}->[0]->parameters->{VALUE} // "" ) eq "DATE" ) {

		( my $t = $e->start->add_duration($delta)->date ) =~ s/-//g;
		delete( $e->properties->{dtstart} );
		$e->add_property( "dtstart",
				  [ $t, { VALUE => "DATE" } ] );
		( $t = $e->end->add( nanoseconds => 1 )->add_duration($delta)->date ) =~ s/-//g;
		delete( $e->properties->{dtend} );
		$e->add_property( "dtend",
				  [ $t, { VALUE => "DATE" } ] );
	    }
	    else {
		$e->start( $e->start->add_duration($delta) );
		$e->end( $e->end->add_duration($delta) );
	    }
	    delete( $e->properties->{duration} );
	    last_modified($e);
	    $rewrite++;
	}
	elsif ( $verbose ) {
	    warn("$file: Up to date\n");
	}
    }

    rewrite( $c, $file ) if $rewrite;
}

sub ffhandler {
    return unless -f -r -s && $_ =~ /\.ics$/i;
    open( my $fd, '<:utf8', $File::Find::name )
      or die("$File::Find::name: $!\n");
    my $data = do { local $/; <$fd> };
    close($fd);
    return unless $data =~ /^summary:$floatsym/mi;
    shift_float( $File::Find::name,
		 Data::ICal->new( data => $data ) );
}

sub dir_float {
    my ( @dirs ) = @_;
    use File::Find;
    find( { no_chdir => 1, wanted => \&ffhandler }, @dirs );
}

sub fetch {
    my ( $file ) = @_;

    open( my $fd, '<:utf8', $file )
      or die("$file: $!\n");
    my $data = do { local $/; <$fd> };
    close($fd);

    Data::ICal->new( data => $data );
}

sub rewrite {
    my ( $c, $file ) = @_;

    if ( $rewrite ) {
	warn("Updating: $file\n") if $verbose;
	rename( $file, "$file~" ) || die;
	open( my $fd, '>:utf8', $file );
	print $fd $c->as_string;
	close($fd);
    }
    else {
	binmode( STDOUT, ':utf8' );
	print( "=== $file ===\n", $c->as_string );
    }
}

sub Data::ICal::Entry::Event::status {
    my $self = shift;
    return $self->_simple_property('status', @_);
}

sub last_modified {
    my ( $e, $new ) = @_;
    $new  //= time;

    delete( $e->properties->{last_modified} );
    my $t = DateTime->from_epoch( epoch => $new );
    $t = $t->ymd("") . "T" . $t->hms("") . "Z";
    $e->add_property( "last-modified",
		      [ $t, { VALUE => "DATE-TIME" } ] );
}

exit 0;

################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally
    my $man = 0;		# handled locally

    my $pod2usage = sub {
        # Load Pod::Usage only if needed.
        require Pod::Usage;
        Pod::Usage->import;
        &pod2usage;
    };

    my $local_float;

    # Process options.
    if ( @ARGV > 0 ) {
	GetOptions('ident'	=> \$ident,
		   'verbose+'	=> \$verbose,
		   'quiet'	=> sub { $verbose = 0 },
		   'float!'	=> \$local_float,
		   'shift'	=> sub { $action = 0  },
		   'rewrite!'	=> \$rewrite,
		   'trace'	=> \$trace,
		   'help|?'	=> \$help,
		   'man'	=> \$man,
		   'debug'	=> \$debug)
	  or $pod2usage->(2);
    }
    if ( $ident or $help or $man ) {
	print STDERR ("This is $my_package [$my_name $my_version]\n");
    }
    if ( $man or $help ) {
	$pod2usage->(1) if $help;
	$pod2usage->(VERBOSE => 2) if $man;
    }
    if ( defined($local_float) ) {
	$action = $local_float ? 1 : -1;
    }
}

__END__

################ Documentation ################

=head1 NAME

vdirfloat - floating appointments using vdir

=head1 SYNOPSIS

vdirfloat [options] [file or dir ...]

vdirfloat { --float | --no-float } [options] [file ...]

 Options:
   --rewrite		rewrite (update) the .ics if needed
   --ident		shows identification
   --help		shows a brief help message and exits
   --man                shows full documentation and exits
   --verbose		provides more verbose information
   --quiet		since verbose information

=head1 OPTIONS

=over 8

=item B<--rewrite>

If an .ics file needs updating, it is rewritten in place. This is
the default behaviour.

=item B<--no-rewrite>

If an .ics file needs updating, the updated content is written to
standard output. Mostly for debugging.

=item B<--float>

Takes one or more .ics files, and marks them as floating appointments.

Note that appointments that are marked C<Confirmed> are skipped.

=item B<--no-float>

Takes one or more .ics files, and unmarks them as floating appointments.

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

Provides more verbose information.

=item B<--quiet>

Silences verbose information.

=item I<file or dir>

The input files or directories to process.

=back

=head1 DESCRIPTION

B<vdirfloat> implements floating appointments using a vdir.

For information about vdirs, see L<https://vdirsyncer.pimutils.org/en/stable/index.html>.

A floating appointment is a todo-like appointment that gets shifted to
the current day. So it will stay on the today's list of appointments
until it is marked completed.

Since calendar clients do not know about floating appointments, the
functionality is emulated as follows:

=over

=item *

An appointment is floating if its description starts with a special
symbol, C<U+21AA>, which looks like an arrow with a hook. If you or
your editor is smart it will be straighforward to prepend this symbol
to the description of an appointment.

=item *

To stop the appointment from floating, just remove the C<U+21AA> from
the description, or mark the appointment as C<Confirmed> (most
calendar clients can do that for you).

=back

By default, B<vdirfloat> will process a vdir of calendars with .ics
files, examine each file to detect whether it is a floating
appointment, and update the date to today's date. This needs to be
done once per day, preferrable close after midnight. A C<cron> task or
equivalent can do that for you.

With B<--float> option, it will mark one or more .ics files (not
directories!) to be floating appointment.
Note that appointments that are marked C<Confirmed> are skipped.

With B<--no-float> option, it will unmark one or more .ics files (not
directories!) as floating appointments.

=head1 DEPENDENCIES

<vdirfloat> uses Data::ICal and Data::ICal::DateTime.

=head1 AUTHOR

Johan Vromans C<< <jv at CPAN dot org > >>

=head1 SUPPORT

vdirfloat development is hosted on GitHub, repository
L<https://github.com/sciurius/vdirfloat>.

Please report any bugs or feature requests to the GitHub issue tracker,
L<https://github.com/sciurius/vdirfloat/issues>.

=head1 LICENSE

Copyright (C) 2018 Johan Vromans,

This program is free software. You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

