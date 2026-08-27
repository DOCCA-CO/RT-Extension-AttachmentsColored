# Configuration template for upload test scripts
# Copy this file and modify the values for your NextCloud setup
{
    base_url      => 'http://nextcloud.local',           # Your NextCloud base URL
    client_id     => 'your-oauth-client-id',             # OAuth2 client ID
    client_secret => 'your-oauth-client-secret',         # OAuth2 client secret
    redirect_uri  => 'http://localhost',                 # OAuth2 redirect URI
    user_id       => 'robot',                            # NextCloud username
    test_folder   => '/Storage',                         # Default test folder
}