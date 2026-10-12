#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use URI::Escape;
use XML::LibXML;
use JSON;

# ====== CONFIGURATION ======
my $nextcloud_base = 'http://nextcloud.local/remote.php/dav/files/robot';
my $access_token   = 'RxyUhDa56AFSKaY27FVB2vd7MCMN1O0Qxq1bZSFrFQ55Bd9BakZR8SBEfeQsZ8rYla6Mu3WB';  # your OAuth2 access token
my $src_folder     = '/Projects/Sablon mappa';
my $dst_folder     = '/Projects/NewCopy';

# ====== INIT ======
my $ua = LWP::UserAgent->new;
$ua->ssl_opts(verify_hostname => 0);

# ====== MAIN ======
copy_folder_recursive($src_folder, $dst_folder);

sub copy_folder_recursive {
    my ($src, $dst) = @_;

    unless (folder_exists($dst)) {
        print "Creating folder: $dst\n";
        mkcol($dst);
    }

    my @items = list_folder($src);
    foreach my $item (@items) {
        my $name = $item->{name};
        my $type = $item->{type};

        next if $name eq '';  # skip self
        my $src_path = "$src/$name";
        my $dst_path = "$dst/$name";

        if ($type eq 'collection') {
            copy_folder_recursive($src_path, $dst_path);
        } else {
            copy_file($src_path, $dst_path);
        }
    }
}

sub folder_exists {
    my ($path) = @_;
    my $url = "$nextcloud_base/" . uri_escape($path);
    my $req = HTTP::Request->new(HEAD => $url);
    $req->header('Authorization' => "Bearer $access_token");
    my $res = $ua->request($req);
    return $res->is_success;
}

sub mkcol {
    my ($path) = @_;
    my $url = "$nextcloud_base/" . uri_escape($path);
    my $req = HTTP::Request->new(MKCOL => $url);
    $req->header('Authorization' => "Bearer $access_token");
    my $res = $ua->request($req);
    return $res->is_success;
}

sub copy_file {
    my ($src, $dst) = @_;
    my $src_url = "$nextcloud_base/" . uri_escape($src);
    my $dst_url = "$nextcloud_base/" . uri_escape($dst);
    print "Copying file: $src -> $dst\n";
    my $req = HTTP::Request->new('COPY' => $src_url);
    $req->header(
        'Authorization' => "Bearer $access_token",
        'Destination'   => $dst_url,
    );
    my $res = $ua->request($req);
    unless ($res->is_success) {
        warn "Failed to copy $src: " . $res->status_line . "\n";
    }
}

sub list_folder {
    my ($path) = @_;
    my $url = "$nextcloud_base/" . uri_escape($path) . '/';
    my $req = HTTP::Request->new('PROPFIND' => $url);
    $req->header(
        'Depth'         => 1,
        'Authorization' => "Bearer $access_token"
    );
    $req->content('<?xml version="1.0"?>
        <d:propfind xmlns:d="DAV:">
          <d:prop><d:resourcetype/><d:displayname/></d:prop>
        </d:propfind>');

    my $res = $ua->request($req);
    die "Failed to list folder $path: " . $res->status_line unless $res->is_success;

    my $parser = XML::LibXML->new;
    my $doc    = $parser->parse_string($res->decoded_content);

    my @items;
    for my $resp ($doc->findnodes('//d:response')) {
        my $href  = $resp->findvalue('./d:href');
        my $name  = $href;
        $name =~ s{.*/([^/]+)/?$}{$1};
        my $isdir = ($resp->findnodes('.//d:collection')) ? 1 : 0;
        push @items, { name => $name, type => ($isdir ? 'collection' : 'file') };
    }
    return @items;
}
