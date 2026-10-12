package RT::Extension::NextCloud::Files;
use base qw(RT::Extension::NextCloud);

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use JSON qw(encode_json decode_json);
use Encode qw(encode_utf8 decode_utf8);
use MIME::Base64;
use URI::Escape qw(uri_escape_utf8);
use File::Basename;
use File::Spec;
use Carp;
use XML::Simple;

our $VERSION = '0.01';
my $token_file = 'token_store.json';

sub new {
    my ($class, %args) = @_;
    for my $p (qw/base_url client_id client_secret/) {
        croak "Missing required param: $p" unless $args{$p};
    }
    my $self = {
        base_url => $args{base_url},
        redirect_uri => $args{redirect_uri} || 'http://localhost',
        user_id => $args{user_id} || undef,
        password => $args{password} || undef,
        client_id => $args{client_id},
        client_secret => $args{client_secret},
        access_token => undef,
        expires_in => undef,
        refresh_token => undef,
        token_type => undef,
        token_file => $args{token_file} || 'fl_token_store.json',
        ua => LWP::UserAgent->new(timeout => 30),
    };
    bless $self, $class;
    return $self;
}

sub access_token {
    my $self = shift;
    my $token = $self->_load_token();
    $self->{created_at} = $token->{created_at};
    $self->{access_token} = $token->{access_token};
    $self->{expires_in} = $token->{expires_in};
    $self->{refresh_token} = $token->{refresh_token};
    $self->{token_type} = $token->{token_type};
    if ($self->_is_expired($token)) {
        my $res = $self->{ua}->post($self->{base_url}."/index.php/apps/oauth2/api/v1/token", {
            grant_type    => 'refresh_token',
            refresh_token => $self->{refresh_token},
        }, 'Authorization' => 'Basic ' . MIME::Base64::encode(sprintf("%s:%s", $self->{client_id}, $self->{client_secret}), ''));
        if ($res->is_success) {
            my $new_token = decode_json($res->decoded_content);
            $new_token->{created_at} = time();
            $self->_save_token($new_token);
            $self->{created_at} = $new_token->{created_at};
            $self->{access_token} = $new_token->{access_token};
            $self->{expires_in} = $new_token->{expires_in};
            $self->{refresh_token} = $new_token->{refresh_token};
            $self->{token_type} = $new_token->{token_type};
        } else {
            croak "Failed to refresh token: " . $res->status_line;
        }
    }
    return $self->{access_token};
}

sub create_folder {
    my ($self, $folder_name) = @_;
    
    # Validate required parameter
    croak "Missing required parameter: folder_name" unless defined $folder_name;
    
    # Prepare the WebDAV URL for folder creation
    my $webdav_url = $self->{base_url} . '/remote.php/dav/files';
    
    # Clean up folder path (remove leading/trailing slashes, ensure it starts with /)
    my $folder_path = $self->{user_id} . '/' . $folder_name;
    $folder_path =~ s|^/+||;  # Remove leading slashes
    $folder_path =~ s|/+$||;  # Remove trailing slashes
    $folder_path = '/' . $folder_path if $folder_path;  # Add single leading slash
        
    my $folder_url = "$webdav_url$folder_path";
    
    # Get access token
    my $token = $self->access_token();
    unless ($token) {
        warn "Failed to get access token";
        return undef;
    }
    
    # Create HTTP request for folder creation using WebDAV MKCOL
    my $request = HTTP::Request->new('MKCOL', $folder_url);
    $request->header('Authorization' => "Bearer " . $self->{access_token});
    
    # Send the request
    my $response = $self->{ua}->request($request);
    
    # Debug logging
    warn "NextCloud Create Folder Debug - URL: $folder_url, Response Code: " . $response->code if $ENV{RT_DEBUG_NEXTCLOUD};
    
    if ($response->is_success || $response->code == 201) {
        return {
            success => 1,
            message => "Folder created successfully",
            folder_path => $folder_path,
            folder_url => $self->create_share_link($folder_url, (share_type => 1, permissions => 15))
        };
    } elsif ($response->code == 405) {
        # 405 Method Not Allowed usually means folder already exists
        return {
            success => 0,
            message => "Folder already exists",
            folder_path => $folder_path,
            folder_url => $self->create_share_link($folder_url, (share_type => 1, permissions => 15))
        };
    } else {
        croak "Failed to create folder:  $folder_url " . $response->status_line . ": " . $response->content;
    }
}

sub upload_file {
    my ($self, %args) = @_;
    
    # Validate required parameters
    for my $param (qw/content folder remote_file/) {
        croak "Missing required parameter: $param" unless defined $args{$param};
    }
    
    my $local_file = $args{local_file} || undef;
    my $content = $args{content} || undef;
    my $folder = $self->{user_id} . '/' . $args{folder};
    my $remote_file = $args{remote_file};
    
    # Check if local file exists
    # unless (-f $local_file) {
    #     croak "Local file does not exist: $local_file";
    # }
    
    # Read file content
    # open my $fh, '<:raw', $local_file or croak "Cannot open file $local_file: $!";
    # local $/;
    # my $file_content = <$fh>;
    # close $fh;
    
    # Prepare the upload URL - NextCloud WebDAV endpoint
    my $webdav_url = $self->{base_url} . '/remote.php/dav/files';

    #print "WebDAV URL: $webdav_url\n"; # Debugging line

    # Clean up folder path (remove leading/trailing slashes, ensure it starts with /)
    $folder =~ s|^/+||;  # Remove leading slashes
    $folder =~ s|/+$||;  # Remove trailing slashes
    $folder = '/' . $folder if $folder;  # Add single leading slash
    
    # URL encode the remote filename to handle special characters
    my $encoded_remote_file = uri_escape_utf8($remote_file);
    
    # Construct the full remote path with proper encoding
    my $remote_path = $folder ? "$folder/$encoded_remote_file" : $encoded_remote_file;
    # Ensure the path starts with a forward slash for WebDAV
    $remote_path = '/' . $remote_path unless $remote_path =~ m|^/|;
    
    my $upload_url = "$webdav_url$remote_path";

    #print "Upload URL: $upload_url\n"; # Debugging line

    # Get access token
    my $token = $self->access_token();
    #print "Access Token: $token\n"; # Debugging line
    unless ($token) {
        warn "Failed to get access token";
        return undef;
    }

    # Create HTTP request for file upload using WebDAV PUT
    my $request = HTTP::Request->new('PUT', $upload_url);
    $request->header('Authorization' => "Bearer " . $self->{access_token});
    $request->header('Content-Type' => 'application/octet-stream');
    $request->content($content);
    
    # Send the request
    my $response = $self->{ua}->request($request);

    # Debug logging
    warn "NextCloud Upload Debug - URL: $upload_url, Response Code: " . $response->code . ", Content-Length: " . length($content) if $ENV{RT_DEBUG_NEXTCLOUD};

    if ($response->is_success || $response->code == 201) {
        my $result = {
            success => 1,
            message => "File uploaded successfully",
            remote_path => $remote_path,
            upload_url => $upload_url
        };
        
        # Generate public share link if requested
        if ($args{create_share_link}) {
            # For share creation, we need the path relative to user's home (using original filename, not encoded)
            my $user_relative_path = $args{folder} . '/' . $remote_file;
            $user_relative_path =~ s|^/+||;  # Remove leading slashes
            my $share_link = $self->create_share_link($user_relative_path, %args);
            $result->{share_link} = $share_link if $share_link;
        }
        
        return $result;
    } else {
        croak "Failed to upload file: " . $response->status_line . ": " . $response->content;
    }
}

sub create_share_link {
    my ($self, $file_path, %args) = @_;
    
    # Default share options
    my $share_type = $args{share_type} || 1;  # 3 = public link, 1 = group share, 0 = user share
    my $permissions = $args{permissions} || 15;  # 1 = read, 15 = read/write/delete
    my $password = $args{password} || '';
    my $expire_date = $args{expire_date} || '';
    
    # Prepare the OCS API endpoint for creating shares
    my $ocs_url = $self->{base_url} . '/ocs/v2.php/apps/files_sharing/api/v1/shares';
    
    # Get access token
    my $token = $self->access_token();
    unless ($token) {
        warn "Failed to get access token for share creation";
        return undef;
    }
    
    # Prepare share creation parameters
    # The path should be relative to user's home directory
    my %share_params = (
        path => '/' . $file_path,
        shareType => $share_type,
        permissions => $permissions,
    );
    
    # Add optional parameters
    $share_params{password} = $password if $password;
    $share_params{expireDate} = $expire_date if $expire_date;
    
    # Create HTTP request for share creation
    my $request = HTTP::Request->new('POST', $ocs_url);
    $request->header('Authorization' => "Bearer " . $self->{access_token});
    $request->header('OCS-APIRequest' => 'true');
    $request->header('Content-Type' => 'application/x-www-form-urlencoded');
    
    # Encode parameters
    my $content = join '&', map { "$_=" . URI::Escape::uri_escape($share_params{$_}) } keys %share_params;
    $request->content($content);
    
    # Send the request
    my $response = $self->{ua}->request($request);
    
    if ($response->is_success) {
        my $content = $response->decoded_content;
        
        # Parse XML response (NextCloud OCS API returns XML by default)
        if ($content =~ /<url>(.*?)<\/url>/) {
            my $share_url = $1;
            # Decode HTML entities
            $share_url =~ s/&lt;/</g;
            $share_url =~ s/&gt;/>/g;
            $share_url =~ s/&amp;/&/g;
            return $share_url;
        } elsif ($content =~ /<message>(.*?)<\/message>/) {
            warn "Share creation failed: $1";
            return undef;
        }
    } else {
        warn "Failed to create share link: " . $response->status_line . ": " . $response->content;
        return undef;
    }
    
    return undef;
}

sub list_folder {
    my ($self, $source_path) = @_;

    # Validate required parameter
    croak "Missing required parameter: source_path" unless defined $source_path;
    my $token = $self->access_token();
    unless ($token) {
        warn "Failed to get access token for share creation";
        return undef;
    }
    
    # Prepare the WebDAV URL for folder listing
    my $webdav_url = $self->{base_url} . '/remote.php/dav/files';

    # Clean up source path
    my $folder_path = $self->{user_id} . '/' . $source_path;
    $folder_path =~ s|^/+||;  # Remove leading slashes
    $folder_path =~ s|/+$||;  # Remove trailing slashes
    $folder_path = '/' . $folder_path if $folder_path;  # Add single leading slash
    
    # URL encode the path
    my $encoded_path = $folder_path;
    my $list_url = "$webdav_url$encoded_path";

    # Create HTTP request for folder listing using WebDAV PROPFIND
    my $request = HTTP::Request->new('PROPFIND', $list_url);
    $request->header('Authorization' => "Bearer " . $self->{access_token});
    $request->header('Depth' => '1');
    $request->header('Content-Type' => 'application/xml');
    
    # PROPFIND XML body to request file properties
    my $propfind_body = <<'XML';
<?xml version="1.0" encoding="UTF-8"?>
    <d:propfind xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns" xmlns:nc="http://nextcloud.org/ns">
      <d:prop>
        <d:getlastmodified/>
        <d:getcontentlength/>
        <d:getcontenttype/>
        <oc:permissions/>
        <d:resourcetype/>
        <d:getetag/>
      </d:prop>
    </d:propfind>
XML
    
    $request->content($propfind_body);
    
    # Send the request
    my $response = $self->{ua}->request($request);
    
    # Debug logging
    warn "NextCloud List Folder Debug - URL: $list_url, Response Code: " . $response->code if $ENV{RT_DEBUG_NEXTCLOUD};
    
    if ($response->is_success) {
        my $xml_content = $response->decoded_content;
        
        # Parse XML response
        my $xml = XML::Simple->new();
        my $data = eval { $xml->XMLin($xml_content, ForceArray => ['response'], KeyAttr => []) };
        
        if ($@) {
            warn "Failed to parse XML response: $@";
            return [];
        }
        
        my @items = ();
        # Process each response (skip the first one as it's the folder itself)

        if ($data->{'d:response'} && ref( $data->{'d:response'} ) eq 'ARRAY') {
            for my $i (1 .. $#{$data->{'d:response'}}) {
                my $item = $data->{'d:response'}->[$i];
                my $href = $item->{'d:href'};
                
                # Extract filename from href
                my $name = $href;
                $name =~ s|/$||;  # Remove trailing slash if present
                $name =~ s|.*/||;  # Get last part of path
                $name = URI::Escape::uri_unescape($name);  # Decode URL encoding
                next if $name eq '' || $name eq '.';  # Skip empty or current dir
                
                # Determine type based on resourcetype
                my $type = 'file';
                if (ref($item->{'d:propstat'}) eq 'ARRAY') {
                    if ($item->{'d:propstat'}->[0]->{'d:prop'}->{'d:resourcetype'}->{'d:collection'}) {
                        $type = 'directory';
                    }
                }
                
                push @items, {
                    type => $type,
                    name => URI::Escape::uri_escape($name)
                };
            }
        }
        
        return \@items;
    } else {
        croak "Failed to list folder: " . $response->status_line . ": " . $response->content;
    }
}

sub copy_file {
    my ($self, $source_path, $dest_path) = @_;
    
    # Validate required parameters
    croak "Missing required parameter: source_path" unless defined $source_path;
    croak "Missing required parameter: dest_path" unless defined $dest_path;
    my $token = $self->access_token();
    unless ($token) {
        warn "Failed to get access token for share creation";
        return undef;
    }
    
    # Prepare the WebDAV URL
    my $webdav_url = $self->{base_url} . '/remote.php/dav/files';
    
    # Clean up source path
    my $src_path = $self->{user_id} . '/' . $source_path;
    $src_path =~ s|^/+||;  # Remove leading slashes
    $src_path =~ s|/+$||;  # Remove trailing slashes
    $src_path = '/' . $src_path if $src_path;  # Add single leading slash
    
    # Clean up destination path
    my $dst_path = $self->{user_id} . '/' . $dest_path;
    $dst_path =~ s|^/+||;  # Remove leading slashes
    $dst_path =~ s|/+$||;  # Remove trailing slashes
    $dst_path = '/' . $dst_path if $dst_path;  # Add single leading slash
    
    # URL encode paths
    my $encoded_src_path = uri_escape_utf8($src_path);
    my $encoded_dst_path = uri_escape_utf8($dst_path);
    
    my $source_url = "$webdav_url$src_path";
    my $dest_url = "$webdav_url$dst_path";
    
    # Create HTTP request for file copy using WebDAV COPY
    my $request = HTTP::Request->new('COPY', $source_url);
    $request->header('Authorization' => "Bearer " . $self->{access_token});
    $request->header('Destination' => $dest_url);
    $request->header('Overwrite' => 'F');  # Don't overwrite existing files
    
    # Send the request
    my $response = $self->{ua}->request($request);
    
    # Debug logging
    warn "NextCloud Copy File Debug - Source: $source_url, Dest: $dest_url, Response Code: " . $response->code if $ENV{RT_DEBUG_NEXTCLOUD};
    
    if ($response->is_success || $response->code == 201) {
        return {
            success => 1,
            message => "File copied successfully",
            source_path => $src_path,
            dest_path => $dst_path,
            source_url => $source_url,
            dest_url => $dest_url
        };
    } elsif ($response->code == 412) {
        # 412 Precondition Failed usually means destination already exists
        return {
            success => 0,
            message => "Destination file already exists",
            source_path => $src_path,
            dest_path => $dst_path
        };
    } else {
        croak "Failed to copy file: " . $response->status_line . ": " . $response->content;
    }
}

## helpers to save/load token from file
sub _save_token {
    my ($self, $data) = @_;
    open my $fh, '>', $self->{token_file} or croak "Cannot save $self->{token_file}: $!";
    print $fh encode_json($data);
    close $fh;
}

sub _load_token {
    my ($self) = @_;
    return unless -f $self->{token_file};
    open my $fh, '<', $self->{token_file} or return;
    local $/;
    my $json = <$fh>;
    close $fh;
    return decode_json($json);
}

sub _is_expired {
    my ($t) = @_;
    return (time() > $t->{created_at} + $t->{expires_in} - 30); # refresh 30s before expiry
}

sub random_code {
    my $length = shift || 16;
    my @chars = ('A'..'Z', 'a'..'z', '0'..'9');
    my $code = '';
    $code = join '', map { $chars[rand @chars] } 1..$length;
    return $code;
}




1;