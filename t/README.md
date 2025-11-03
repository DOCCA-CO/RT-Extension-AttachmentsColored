# Upload Test Scripts

This directory contains test scripts for the RT-Extension-AttachmentsColored file upload functionality.

## Available Scripts

### 1. `test_upload.pl` - Comprehensive Upload Test
A full-featured test script with multiple options and verbose output.

**Usage:**
```bash
# Basic test with auto-generated test file
./test_upload.pl

# Upload a specific file
./test_upload.pl --file /path/to/document.pdf

# Upload to a specific folder with verbose output
./test_upload.pl --folder /projects/rt --verbose

# Create and upload a test file with public share link
./test_upload.pl --create-test-file --folder /testing --share-link

# Upload with password-protected share link
./test_upload.pl --file document.pdf --share-link --password secretpass

# Use custom configuration
./test_upload.pl --config my_config.pl
```

**Options:**
- `-h, --help`: Show help message
- `-c, --config FILE`: Load configuration from file
- `-f, --file FILE`: Upload specific file
- `--folder FOLDER`: Upload to specific folder (default: /test_uploads)
- `-n, --filename NAME`: Use specific remote filename
- `--create-test-file`: Create a temporary test file
- `-s, --share-link`: Create a public share link for the uploaded file
- `-p, --password PASS`: Set password for the share link (requires --share-link)
- `-v, --verbose`: Verbose output

### 2. `simple_upload_test.pl` - Quick Test
A minimal script for quick upload testing with share link creation.

**Usage:**
```bash
./simple_upload_test.pl
```

**Features:**
- Automatically creates a test file
- Uploads to NextCloud
- Creates a public share link for the uploaded file

### 3. `token.pl` - Token Management
Handles OAuth2 token acquisition and refresh for NextCloud.

**Usage:**
```bash
./token.pl
```

## Configuration

### Default Configuration
The scripts use the configuration values from `../etc/AttachmentsColored_Config.pm` by default.

### Custom Configuration
Create a custom configuration file based on `config_template.pl`:

```perl
# my_config.pl
{
    base_url      => 'https://your-nextcloud.com',
    client_id     => 'your-oauth-client-id',
    client_secret => 'your-oauth-client-secret',
    user_id       => 'your-username',
    test_folder   => '/your-test-folder',
}
```

## Prerequisites

1. **NextCloud OAuth2 Setup**: Ensure OAuth2 is properly configured in your NextCloud instance
2. **Perl Dependencies**: The following Perl modules are required:
   - LWP::UserAgent
   - JSON
   - MIME::Base64
   - File::Temp
   - URI::Escape

3. **Token Authentication**: Run `token.pl` first to obtain and store OAuth2 tokens

## Share Link Feature

The upload scripts now support creating public share links for uploaded files. This feature uses NextCloud's OCS (Open Collaboration Services) API to generate shareable URLs.

### Share Link Options

- **Basic share link**: `--share-link` creates a public read-only link
- **Password-protected**: `--share-link --password yourpass` creates a password-protected link
- **Programmatic access**: Use `create_share_link => 1` in the `upload_file()` method

### Share Link Parameters

When using the `upload_file` method programmatically, you can specify:

```perl
$result = $nextcloud->upload_file(
    local_file        => $file_path,
    folder           => '/uploads',
    remote_file      => 'document.pdf',
    create_share_link => 1,           # Enable share link creation
    password         => 'secret123',  # Optional password protection
    permissions      => 1,            # 1=read, 15=read/write/delete
    expire_date      => '2025-12-31', # Optional expiration date (YYYY-MM-DD)
);

# Access the share link
if ($result->{share_link}) {
    print "Share link: $result->{share_link}\n";
}
```

## Token Setup Process

1. Run the token script:
   ```bash
   ./token.pl
   ```

2. Follow the OAuth2 authorization flow:
   - Open the provided URL in a browser
   - Authorize the application
   - Copy the authorization code from the redirect URL
   - Paste it when prompted

3. The token will be saved to `token_store.json` for future use

## Troubleshooting

### Common Issues

1. **"Failed to get access token"**
   - Run `token.pl` to refresh/obtain tokens
   - Check NextCloud OAuth2 configuration

2. **"Local file does not exist"**
   - Verify the file path is correct
   - Use `--create-test-file` to generate a test file

3. **"Upload failed: 401 Unauthorized"**
   - Token may be expired, run `token.pl` again
   - Verify client_id and client_secret

4. **"Upload failed: 404 Not Found"**
   - Check if the target folder exists
   - Verify the user has write permissions

### Debug Mode
Use the `--verbose` flag with `test_upload.pl` for detailed output and debugging information.

## Examples

### Test with Existing File
```bash
./test_upload.pl --file ~/Documents/test.pdf --folder /rt_attachments --verbose
```

### Quick Test
```bash
./simple_upload_test.pl
```

### Custom Configuration Test
```bash
cp config_template.pl my_config.pl
# Edit my_config.pl with your settings
./test_upload.pl --config my_config.pl --create-test-file
```