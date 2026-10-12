#!/usr/bin/env perl
use strict;
use warnings;
use LWP::UserAgent;
use JSON qw(decode_json encode_json);
use URI::Escape;
use MIME::Base64; 
use Time::HiRes qw(time);

# -----------------------------
# CONFIGURATION
# -----------------------------
my $nextcloud_base   = 'http://nextcloud.local';
my $client_id        = 'GhPpxjfgPzxZEEMizqQX39mQTdSpyFyyysKhHrVQ2JzWryxrQYIJJJxaxisGqxr0';
my $client_secret    = 'ukPKqYVTAPCmLFiVC9gXPh06QGtUeoEu1mNELh7LkMUvfDHwUjcYOg0XSXSFNnIy';
my $redirect_uri     = 'http://localhost:8080/Admin/NextCloudFiles/';
my $token_file       = '/opt/rt5/var/fl_token_store.json';

my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
$ua->timeout(15);

# -----------------------------
# HELPER FUNCTIONS
# -----------------------------
sub save_token {
    my ($data) = @_;
    open my $fh, '>', $token_file or die "Cannot save $token_file: $!";
    print $fh encode_json($data);
    close $fh;
}

sub load_token {
    return unless -f $token_file;
    open my $fh, '<', $token_file or return;
    local $/;
    my $json = <$fh>;
    close $fh;
    return decode_json($json);
}

# -----------------------------
# STEP 1: Load or request token
# -----------------------------
my $token = load_token();

if (!$token) {
    print "\n==> First-time setup:\n";
    print "Open this URL in a browser and authorize:\n\n";
    my $auth_url = "$nextcloud_base/index.php/apps/oauth2/authorize?" .
                   "response_type=code&client_id=$client_id" .
                   "&redirect_uri=" . uri_escape($redirect_uri) .
                   "&state=xyz123";
    print "$auth_url\n\n";
    print "Paste the 'code' you get from redirect URL: ";
    chomp(my $auth_code = <STDIN>);

    my $res = $ua->post("$nextcloud_base/index.php/apps/oauth2/api/v1/token", {
        grant_type   => 'authorization_code',
        code         => $auth_code,
        redirect_uri => $redirect_uri,
    }, 'Authorization' => 'Basic ' . MIME::Base64::encode("$client_id:$client_secret", ''));

    die "Token request failed: " . $res->status_line . "\n" . $res->decoded_content
        unless $res->is_success;

    $token = decode_json($res->decoded_content);
    $token->{created_at} = time();
    save_token($token);

    print "Access token obtained and saved.\n";
}

# -----------------------------
# STEP 2: Check if expired
# -----------------------------
sub is_expired {
    my ($t) = @_;
    return (time() > $t->{created_at} + $t->{expires_in} - 30); # refresh 30s before expiry
}

if (is_expired($token)) {
    print "Access token expired. Refreshing...\n";

    my $res = $ua->post("$nextcloud_base/index.php/apps/oauth2/api/v1/token", {
        grant_type    => 'refresh_token',
        refresh_token => $token->{refresh_token},
    }, 'Authorization' => 'Basic ' . MIME::Base64::encode("$client_id:$client_secret", ''));

    if ($res->is_success) {
        my $new_token = decode_json($res->decoded_content);
        $new_token->{created_at} = time();
        save_token($new_token);
        $token = $new_token;
        print "Refreshed successfully.\n";
    } else {
        die "Failed to refresh token: " . $res->status_line;
    }
}

# -----------------------------
# STEP 3: Use token in API call
# -----------------------------
print "Using access token...\n";

my $res = $ua->get("$nextcloud_base/remote.php/dav/files/robot/",
    'Authorization' => "Bearer $token->{access_token}"
);

if ($res->is_success) {
    print "✅ API call successful:\n";
    print $res->decoded_content . "\n";
} else {
    print "❌ API call failed: " . $res->status_line . "\n";
    print $res->decoded_content . "\n";
}
