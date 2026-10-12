#!/usr/bin/env perl
#
# Test Upload Script for RT-Extension-AttachmentsColored
# This script tests file upload functionality for NextCloud integration
#
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use RT::Extension::NextCloud::Files;
use File::Temp qw(tempfile);
use File::Spec;
use JSON qw(decode_json encode_json);
use Getopt::Long;
use Pod::Usage;

# Configuration (you can modify these as needed)
my $config = {
    base_url      => 'http://nextcloud.local',
    client_id     => 'icLwE1D0RIzZfMPewUXOW5whxIzU5uw0ZmWDeae3DlxFzzJBSknmettVwGiiVIfK',
    client_secret => 'RFFlHcpivmHJ8TMvsFYxaeathhMtbnWzm68SVjK20iU1zG7gvxoaNCQVwUNwwa0x',
    redirect_uri  => 'http://localhost',
    user_id       => 'robot',
    test_folder   => 'Storage',
};

# Command line options
my %opts = (
    help       => 0,
    config     => '',
    file       => '',
    folder     => $config->{test_folder},
    filename   => '',
    create_test_file => 0,
    verbose    => 0,
    share_link => 0,
    password   => '',
);

GetOptions(
    'help|h'            => \$opts{help},
    'config|c=s'        => \$opts{config},
    'file|f=s'          => \$opts{file},
    'folder=s'          => \$opts{folder},
    'filename|n=s'      => \$opts{filename},
    'create-test-file'  => \$opts{create_test_file},
    'verbose|v'         => \$opts{verbose},
    'share-link|s'      => \$opts{share_link},
    'password|p=s'      => \$opts{password},
) or pod2usage(2);

pod2usage(1) if $opts{help};

# Load custom config if provided
if ($opts{config} && -f $opts{config}) {
    eval {
        my $custom_config = do $opts{config};
        %$config = (%$config, %$custom_config) if ref $custom_config eq 'HASH';
    };
    warn "Failed to load config file: $@" if $@;
}

print "=== RT-Extension-AttachmentsColored Upload Test ===\n\n";

# Create NextCloud Files instance
my $nextcloud;
eval {
    $nextcloud = RT::Extension::NextCloud::Files->new(
        base_url      => $config->{base_url},
        client_id     => $config->{client_id},
        client_secret => $config->{client_secret},
        redirect_uri  => $config->{redirect_uri},
        user_id       => $config->{user_id},
    );
    print "✅ NextCloud client initialized successfully\n";
};
if ($@) {
    die "❌ Failed to initialize NextCloud client: $@\n";
}

# Determine file to upload
my $local_file;
my $remote_filename;

if ($opts{create_test_file}) {
    # Create a temporary test file
    ($local_file, $remote_filename) = create_test_file();
    print "📄 Created test file: $local_file\n";
} elsif ($opts{file}) {
    # Use provided file
    $local_file = $opts{file};
    unless (-f $local_file) {
        die "❌ File not found: $local_file\n";
    }
    $remote_filename = $opts{filename} || (File::Spec->splitpath($local_file))[2];
} else {
    # Create a simple test file
    ($local_file, $remote_filename) = create_test_file();
    print "📄 No file specified, created test file: $local_file\n";
}

print "📁 Local file: $local_file\n";
print "📁 Remote folder: $opts{folder}\n";
print "📄 Remote filename: $remote_filename\n\n";

# Test the upload
print "🚀 Starting upload test...\n";

my $result;
eval {
    my %upload_args = (
        local_file  => $local_file,
        folder      => $opts{folder},
        remote_file => $remote_filename,
    );
    
    # Add share link options if requested
    if ($opts{share_link}) {
        $upload_args{create_share_link} = 1;
        $upload_args{password} = $opts{password} if $opts{password};
        print "🔗 Share link creation requested\n";
    }
    
    $result = $nextcloud->upload_file(%upload_args);
};

if ($@) {
    print "❌ Upload failed: $@\n";
    cleanup_temp_file($local_file) if $opts{create_test_file};
    exit 1;
}

if ($result && $result->{success}) {
    print "✅ Upload successful!\n";
    print "   Remote path: $result->{remote_path}\n";
    print "   Upload URL: $result->{upload_url}\n" if $opts{verbose};
    
    # Display share link if created
    if ($result->{share_link}) {
        print "🔗 Public share link: $result->{share_link}\n";
    }
    
    # Test file verification (optional)
    if ($opts{verbose}) {
        print "\n🔍 Verifying upload...\n";
        verify_upload($nextcloud, $result->{remote_path});
    }
} else {
    print "❌ Upload failed: Unknown error\n";
}

# Cleanup
cleanup_temp_file($local_file) if $opts{create_test_file};

print "\n=== Test completed ===\n";

# Helper functions
sub create_test_file {
    my ($fh, $filename) = tempfile(
        'test_upload_XXXXXX', 
        SUFFIX => '.txt',
        DIR => File::Spec->tmpdir(),
        UNLINK => 0
    );
    
    my $content = generate_test_content();
    print $fh $content;
    close $fh;
    
    my $remote_name = 'test_upload_' . time() . '.txt';
    return ($filename, $remote_name);
}

sub generate_test_content {
    my $timestamp = scalar localtime();
    return <<EOF;
RT-Extension-AttachmentsColored Test File
=========================================

This is a test file created for upload testing.

Timestamp: $timestamp
Test ID: test_${\(int(rand(10000)))}
File size: This file contains approximately 500 bytes of test data.

Lorem ipsum dolor sit amet, consectetur adipiscing elit. 
Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. 
Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.

End of test file.
EOF
}

sub cleanup_temp_file {
    my $file = shift;
    unlink $file if $file && -f $file;
    print "🧹 Cleaned up temporary file: $file\n" if $opts{verbose};
}

sub verify_upload {
    my ($client, $remote_path) = @_;
    
    # This would require implementing a download or list method
    # For now, just indicate what we would do
    print "   Note: File verification would require additional API methods\n";
    print "   Remote path to verify: $remote_path\n";
}

__END__

=head1 NAME

test_upload.pl - Test script for RT-Extension-AttachmentsColored file uploads

=head1 SYNOPSIS

test_upload.pl [options]

 Options:
   -h, --help              Show this help message
   -c, --config FILE       Load configuration from file
   -f, --file FILE         Upload specific file
   --folder FOLDER         Upload to specific folder (default: /test_uploads)
   -n, --filename NAME     Use specific remote filename
   --create-test-file      Create a temporary test file
   -s, --share-link        Create a public share link for the uploaded file
   -p, --password PASS     Set password for the share link (requires --share-link)
   -v, --verbose           Verbose output

=head1 DESCRIPTION

This script tests the file upload functionality of the RT-Extension-AttachmentsColored
NextCloud integration. It can upload existing files or create test files for upload.

=head1 EXAMPLES

  # Basic test with auto-generated test file
  ./test_upload.pl

  # Upload a specific file
  ./test_upload.pl --file /path/to/document.pdf

  # Upload to a specific folder with verbose output
  ./test_upload.pl --folder /projects/rt --verbose

  # Create and upload a test file with public share link
  ./test_upload.pl --create-test-file --folder /testing --share-link

  # Upload with password-protected share link
  ./test_upload.pl --file document.pdf --share-link --password secretpass

=head1 CONFIGURATION

The script uses default configuration values that match the NextCloud setup
in the main configuration. You can override these by providing a config file:

  # config.pl
  {
      base_url => 'https://your-nextcloud.com',
      client_id => 'your-client-id',
      client_secret => 'your-client-secret',
      user_id => 'your-username',
  }

Then run: ./test_upload.pl --config config.pl

=head1 AUTHOR

RT-Extension-AttachmentsColored Test Suite

=cut