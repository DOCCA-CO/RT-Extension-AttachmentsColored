Set(%AttachmentCategories, (
	'A' => '#FF6347',
	'B' => '#90EE90',
	'C' => '#87CEFA',
	'D' => '#fCDC8C',
##	'hidden' => '#DCDCDC'
));

Set($ConfigTicketID, 2);

Set($DefaultFolderStructureTicketID, 1);

Set(%RabbitMQ, ('enabled' => 0, 'host' => '', 'port' => 5672, 'login' => '', 'passw' => ''));

Set($GoogleDrive, {
	'enabled' => 0,
	'client_id' => '',
	'client_secret' => '',
	'authorize_url' => 'https://accounts.google.com/o/oauth2/auth',
	'token_url' => 'https://accounts.google.com/o/oauth2/token',
	'api_url' => 'https://www.googleapis.com/drive/v3',
	'redirect_uri' => 'http://localhost:8080',
	'scope' => 'https://www.googleapis.com/auth/drive',
	'refresh_token' => '',
	'default_folder' => '',
	"grant_type"    => "refresh_token",
});

Set($OneDrive, {
	'enabled' => 0,
	'tenant_id' => 'common',
	'authorize_url' => 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
	'token_url' => 'https://login.microsoftonline.com/common/oauth2/v2.0/token',
	'api_url' => 'https://graph.microsoft.com/v1.0',
	'client_id' => '',
	'client_secret' => '',
	'redirect_uri' => 'http://localhost:8080',
	'scope' => 'https://graph.microsoft.com/.default',  ## Files.ReadWrite.All and/or Sites.ReadWrite.All
	'refresh_token' => ''
});

Set($NextCloud, {
	'enabled' => 0,
	'base_url' => 'http://nextcloud.local',
	'authorize_url' => 'http://nextcloud.local/index.php/apps/oauth2/authorize',
	'token_url' => 'http://nextcloud.local/index.php/apps/oauth2/api/v1/token',
	'api_url' => 'http://nextcloud.local/remote.php/dav/files/',
	'client_id' => '',
	'client_secret' => '',
	'redirect_uri' => 'http://localhost:8080/Admin/NextCloudFiles/',
	'default_folder' => 'Storage', ## default folder for NextCloud
	'user' => 'robot',
});


Set($SimpleUpload, {
	'enabled' => 0,
});

# Set the maximum length of the filename to display in the attachment list.
# If the filename is longer than this value, it will be truncated.
# Set to 0 to display the full filename.
Set($FileNameMaxLength, 50);

1;
