#!/usr/bin/env perl
#
# Simple Upload Test Script
# A minimal example for testing NextCloud file uploads
#
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use RT::Extension::NextCloud::Files;
use File::Temp qw(tempfile);

print "=== Simple NextCloud Upload Test ===\n\n";

# Configuration - update these values for your NextCloud instance
my $nextcloud = RT::Extension::NextCloud::Files->new(
    base_url      => 'http://nextcloud.local',
    client_id     => 'GhPpxjfgPzxZEEMizqQX39mQTdSpyFyyysKhHrVQ2JzWryxrQYIJJJxaxisGqxr0',
    client_secret => 'ukPKqYVTAPCmLFiVC9gXPh06QGtUeoEu1mNELh7LkMUvfDHwUjcYOg0XSXSFNnIy',
    redirect_uri  => 'http://localhost',
    user_id       => 'robot',
    token_file    => 'fl_token_store.json',
);

# Create a simple test file
my ($fh, $test_file) = tempfile('simple_test_XXXXXX', SUFFIX => '.txt', UNLINK => 1);
print $fh "Hello NextCloud!\nThis is a simple test file.\nTimestamp: " . scalar(localtime()) . "\n";
close $fh;

print "Created test file: $test_file\n";

# Upload the file
my $remote_filename = 'simple_test_' . time() . '.txt';
my $folder = 'Storage';

print "Uploading to folder: $folder\n";
print "Remote filename: $remote_filename\n\n";

eval {
    my $result = $nextcloud->upload_file(
        content        => "Hello NextCloud!\nThis is a simple test file.\nTimestamp: " . scalar(localtime()) . "\n",
        folder           => $folder,
        remote_file      => $remote_filename,
        create_share_link => 1,  # Enable share link creation
    );
    
    if ($result->{success}) {
        print "✅ SUCCESS: File uploaded successfully!\n";
        print "Remote path: $result->{remote_path}\n";
        
        if ($result->{share_link}) {
            print "🔗 Public share link: $result->{share_link}\n";
        } else {
            print "⚠️  Share link creation failed or not supported\n";
        }
    } else {
        print "❌ FAILED: Upload was not successful\n";
    }
};

if ($@) {
    print "❌ ERROR: $@\n";
}

print "\nTest completed.\n";