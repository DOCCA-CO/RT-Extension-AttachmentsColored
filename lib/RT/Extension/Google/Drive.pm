package RT::Extension::Google::Drive;
use base qw(RT::Extension::Google);

use utf8;
use Encode qw(encode_utf8 decode_utf8);
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON;
use URI::Encode qw(uri_encode uri_decode);

my $C_ERROR = "Error:";

=head2 access_token
Get an access token using OAuth2 previously set up.

Inputs:
   reference to hash of access data
   agent
Output:
   string          if ok
   $C_ERROR: msg   if not ok
=cut

sub access_token {
    my $data_ref = shift;
    my $agent    = shift;

    my $i_am = "access_token()";
    if ((ref($data_ref) eq "") or (ref($data_ref) ne "HASH")) {
        return("${C_ERROR} $i_am: Arg 1 is not a HASH reference");
    }
    if ((not defined($agent)) or ($agent eq "")) {
        $agent = "MyApp/0.1";
    }

    my $data = "";
    foreach my $key (keys(%{$data_ref})) {
        my $value = ${$data_ref}{$key};
        $data .= "$key=$value&";
    }
    chop($data);

    my $tokenURL = 'https://accounts.google.com/o/oauth2/token';

    my $ua = LWP::UserAgent->new;
    $ua->agent($agent);

    my $req = HTTP::Request->new(POST => $tokenURL);
    $req->content_type('application/x-www-form-urlencoded');
    $req->content($data);

    my $res = $ua->request($req);

    if ($res->is_success) {
        my $ref = from_json($res->content);
        my $access_token = $ref->{'access_token'};
        return($access_token);
    } else {
        return("${C_ERROR} $i_am: " . ($res->code eq '501' ? $res->message : $res->status_line));
    }
}

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;

    # Store optional access_token or other init params
    $self->{access_token} = $args{access_token} if $args{access_token};

    return $self;
}


=head2 upload_file
Upload a file to Google Drive using multipart upload.

Inputs:
    $self
    $filename       - the name of the file to create in Drive
    $content_ref    - reference to file content
    $parent_id      - optional parent folder ID
    $mime_type      - MIME type of the file (default: application/octet-stream)
Output:
    hashref with uploaded file metadata
=cut

sub upload_file {
    my ($self, $filename, $content_ref, $parent_id, $mime_type) = @_;

    die "Missing filename or content" unless $filename && $content_ref;

    $mime_type ||= 'application/octet-stream';

    my $metadata = {
        name => $filename,
        mimeType => $mime_type,
    };
    $metadata->{parents} = [$parent_id] if $parent_id;

    my $boundary = "BOUNDARY_" . time;
    my $json_part = to_json($metadata);

    my $body = join(
        "\r\n",
        "--$boundary",
        "Content-Type: application/json; charset=UTF-8",
        "",
        $json_part,
        "--$boundary",
        "Content-Type: $mime_type",
        "",
        $$content_ref,
        "--$boundary--",
        ""
    );

    my $req = HTTP::Request->new(
        POST => 'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'
    );
    $req->header('Authorization' => "Bearer $self->{access_token}");
    $req->header('Content-Type'  => "multipart/related; boundary=$boundary");
    $req->content($body);

    my $ua = LWP::UserAgent->new;
    my $res = $ua->request($req);

    if (!$res->is_success) {
        die "Upload failed: " . $res->status_line . " - " . $res->decoded_content;
    }

    return decode_json($res->decoded_content);
}

1;
