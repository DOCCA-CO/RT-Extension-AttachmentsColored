package RT::Extension::Microsoft::OneDrive;
use base qw(RT::Extension::Microsoft);

use strict;
use warnings;
use LWP::UserAgent;
use JSON qw(encode_json decode_json);
use Carp;

our $VERSION = '0.01';

sub new {
    my ($class, %args) = @_;
    for my $p (qw/tenant_id client_id client_secret/) {
        croak "Missing required param: $p" unless $args{$p};
    }
    my $self = {
        tenant_id     => $args{tenant_id},
        client_id     => $args{client_id},
        client_secret => $args{client_secret},
        access_token  => undef,
        token_expiry  => 0,
        ua            => LWP::UserAgent->new(timeout => 30),
    };
    bless $self, $class;
    return $self;
}

sub access_token {
    my ($self) = @_;
    # Return cached token if still valid
    if ($self->{access_token} && time() < $self->{token_expiry}) {
        return $self->{access_token};
    }

    my $url = "https://login.microsoftonline.com/$self->{tenant_id}/oauth2/v2.0/token";
    my $res = $self->{ua}->post($url, {
        client_id     => $self->{client_id},
        scope         => 'https://graph.microsoft.com/.default',
        client_secret => $self->{client_secret},
        grant_type    => 'client_credentials',
    });

    unless ($res->is_success) {
        croak "Failed to get access token: " . $res->status_line . " - " . $res->decoded_content;
    }

    my $data = decode_json($res->decoded_content);
    $self->{access_token} = $data->{access_token};
    $self->{token_expiry} = time() + $data->{expires_in} - 60; # safety margin

    return $self->{access_token};
}

sub upload_file {
    my ($self, %args) = @_;
    for my $p (qw/file_name content/) {
        croak "Missing required param: $p" unless $args{$p};
    }

    my $base_url;
    if ($args{site_id} && $args{drive_id}) {
        $base_url = "https://graph.microsoft.com/v1.0/sites/$args{site_id}/drives/$args{drive_id}";
    } elsif ($args{drive_id}) {
        $base_url = "https://graph.microsoft.com/v1.0/drives/$args{drive_id}";
    } else {
        $base_url = "https://graph.microsoft.com/v1.0/me/drive";
    }

    my $url = "$base_url/root:/$args{file_name}:/content";
    my $res = $self->{ua}->put(
        $url,
        'Authorization' => "Bearer " . $self->access_token,
        'Content-Type'  => 'application/octet-stream',
        Content         => $args{content},
    );

    unless ($res->is_success) {
        croak "Upload failed: " . $res->status_line . " - " . $res->decoded_content;
    }
    return decode_json($res->decoded_content);
}

sub upload_file_big {
    my ($self, %args) = @_;
    for my $p (qw/file_name content/) {
        croak "Missing required param: $p" unless $args{$p};
    }

    my $base_url;
    if ($args{site_id} && $args{drive_id}) {
        $base_url = "https://graph.microsoft.com/v1.0/sites/$args{site_id}/drives/$args{drive_id}";
    } elsif ($args{drive_id}) {
        $base_url = "https://graph.microsoft.com/v1.0/drives/$args{drive_id}";
    } else {
        $base_url = "https://graph.microsoft.com/v1.0/me/drive";
    }

    # Step 1: Create upload session
    my $session_url = "$base_url/root:/$args{file_name}:/createUploadSession";
    my $session_res = $self->{ua}->post(
        $session_url,
        'Authorization' => "Bearer " . $self->access_token,
        'Content-Type'  => 'application/json',
        Content         => encode_json({}),
    );

    unless ($session_res->is_success) {
        croak "Failed to create upload session: " . $session_res->status_line . " - " . $session_res->decoded_content;
    }

    my $upload_url = decode_json($session_res->decoded_content)->{uploadUrl};

    # Step 2: Upload in chunks
    my $chunk_size = 327680; # 320 KB
    my $size       = length($args{content});
    my $start      = 0;

    while ($start < $size) {
        my $end = $start + $chunk_size - 1;
        $end = $size - 1 if $end >= $size;
        my $chunk = substr($args{content}, $start, $end - $start + 1);

        my $res = $self->{ua}->put(
            $upload_url,
            'Content-Length' => length($chunk),
            'Content-Range'  => "bytes $start-$end/$size",
            Content          => $chunk,
        );

        unless ($res->is_success || $res->code == 202) {
            croak "Chunk upload failed: " . $res->status_line . " - " . $res->decoded_content;
        }

        $start = $end + 1;
    }

    # Last response should have file metadata
    return 1;
}

1;
