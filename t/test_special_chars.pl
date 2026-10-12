#!/usr/bin/env perl
#
# Test NextCloud Upload with Special Characters
# This simulates the RT upload scenario with ticket-prefixed filenames
#
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use RT::Extension::NextCloud::Files;
use MIME::Base64 qw(encode_base64);

print "=== NextCloud Special Characters Upload Test ===\n\n";

# Configuration
my $nextcloud = RT::Extension::NextCloud::Files->new(
    base_url      => 'http://nextcloud.local',
    client_id     => 'GhPpxjfgPzxZEEMizqQX39mQTdSpyFyyysKhHrVQ2JzWryxrQYIJJJxaxisGqxr0',
    client_secret => 'ukPKqYVTAPCmLFiVC9gXPh06QGtUeoEu1mNELh7LkMUvfDHwUjcYOg0XSXSFNnIy',
    redirect_uri  => 'http://localhost',
    user_id       => 'robot',
    token_file    => 'fl_token_store.json',
);

# Test with problematic filename (similar to what RT would generate)
my $test_content = "Test file with special characters in filename\nTimestamp: " . scalar(localtime()) . "\n";
my $ticket_id = 12345;
my $original_filename = "test document with spaces & symbols.txt";

# Test both old (problematic) and new (sanitized) filename formats
my @test_files = (
    {
        name => "Old format (problematic)",
        filename => "#$ticket_id $original_filename",
        should_fail => 1,
    },
    {
        name => "New format (sanitized)",
        filename => "T${ticket_id}_" . ($original_filename =~ s/[^a-zA-Z0-9._-]/_/gr),
        should_fail => 0,
    }
);

foreach my $test (@test_files) {
    print "Testing: $test->{name}\n";
    print "Filename: '$test->{filename}'\n";
    
    eval {
        my $result = $nextcloud->upload_file(
            content => encode_base64($test_content),
            folder => 'Storage',
            remote_file => $test->{filename},
            create_share_link => 1,
        );
        
        if ($result->{success}) {
            print "✅ SUCCESS: File uploaded successfully!\n";
            print "Remote path: $result->{remote_path}\n";
            print "🔗 Share link: $result->{share_link}\n" if $result->{share_link};
        }
    };
    
    if ($@) {
        if ($test->{should_fail}) {
            print "❌ EXPECTED FAILURE: $@\n";
        } else {
            print "🚨 UNEXPECTED FAILURE: $@\n";
        }
    } elsif ($test->{should_fail}) {
        print "🤔 UNEXPECTED SUCCESS: Expected this to fail but it succeeded\n";
    }
    
    print "\n" . ("="x60) . "\n\n";
}

print "Test completed.\n";