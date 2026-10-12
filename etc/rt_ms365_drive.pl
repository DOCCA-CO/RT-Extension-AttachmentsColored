#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Encode qw(encode_utf8 decode_utf8);
use JSON;
use URI;
use URI::Encode 'uri_encode';
use URL::Encode 'url_encode';
use LWP::UserAgent;

use Data::Dumper;
use Carp qw/carp croak/;

my @scope = qw( email Files.Read Files.Read.All Files.Read.Selected Files.ReadWrite Files.ReadWrite.All Files.ReadWrite.AppFolder Files.ReadWrite.Selected offline_access openid profile Sites.Read.All Sites.ReadWrite.All User.Read  );
my $tenant_id = 'common';
my $client_id = '';
my $client_secret = '';
my $redirect_uri = 'https://login.microsoftonline.com/common/oauth2/nativeclient';
my $refresh_token = '';
my $s_scope = uri_encode( join ( ' ',  @scope ) );
my $i_state = int ( 10000 + rand( 1000 ) );

my $debug;

my $href = sprintf('https://login.microsoftonline.com/%s/oauth2/v2.0/authorize?client_id=%s&response_type=code&redirect_uri=%s&response_mode=query&scope=%s&state=%d',
            $tenant_id, $client_id, $redirect_uri, $s_scope, $i_state);

printf "URL: %s\n", $href unless($refresh_token);
unless($refresh_token) {
    print "code=";
    my $code = <STDIN>;
    my %params_step2 = (
        client_id => $client_id,
        scope => $s_scope,
        code => $code,
        redirect_uri => $redirect_uri,
        grant_type => 'authorization_code',
        client_secret => $client_secret
    );

    my $data = "" ;
    # build the list of arguments
        foreach my $key ( keys( %params_step2 ) ) {
        next if( $key eq 'tenant_id' );
        my $value = $params_step2{$key} ;
        $data .= "${key}=${value}&" ;
    }

    chop( $data );

    my $href_step2 = sprintf( 'https://login.microsoftonline.com/%s/oauth2/v2.0/token', $tenant_id );
    my $ua = LWP::UserAgent->new;
    my $agent = "MyApp/1.0";
    $ua->agent( $agent );
    # Create a request
    my $req = HTTP::Request->new( POST => $href_step2 );
    $req->content_type( 'application/x-www-form-urlencoded' );
    $req->content( $data );

    # Pass request to the user agent and get a response back
    my $res = $ua->request( $req );

    my $ref = from_json( $res->content ) ;
    printf "refresh_token: %s\n", ${$ref}{ 'refresh_token' };
}
exit(2) unless($refresh_token);


exit 1;

sub _getToken {
    use Data::Dumper;
    my %params_token = (
        client_id => $client_id,
        scope => $s_scope,
        refresh_token => $refresh_token,
        redirect_uri => $redirect_uri,
        grant_type => 'refresh_token',
        client_secret => $client_secret
    );
    my $data = "" ;
    # build the list of arguments
    foreach my $key ( keys( %params_token ) ) {
        next if( $key eq 'tenant_id' );
        my $value = $params_token{$key};
        $data .= "${key}=${value}&";
    }
    chop( $data );

    my $href_token = sprintf( 'https://login.microsoftonline.com/%s/oauth2/v2.0/token', $tenant_id );
    my $ua = LWP::UserAgent->new;
    my $agent = "MyApp/1.0";
    $ua->agent( $agent );
    # Create a request
    my $req = HTTP::Request->new( POST => $href_token );
    $req->content_type( 'application/x-www-form-urlencoded' );
    $req->content( $data );

    # Pass request to the user agent and get a response back
    my $res = $ua->request( $req );
    my $ref = from_json( $res->content );
    return ${$ref}{access_token} if ( $res->is_success );
    return;
}


1;