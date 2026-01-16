#!/usr/bin/perl

use strict;
use warnings;
use HTTP::Daemon;
use HTTP::Status;
use HTTP::Response;
use URI::Escape;
use File::Path qw(make_path);
use File::Slurp;
use JSON;

my $PORT = 8094;
my $UPLOAD_DIR = '/tmp/perl_uploads';
my $LOG_FILE = 'perl_access.log';
my $CONFIG_FILE = 'perl_config.conf';

make_path($UPLOAD_DIR) unless -d $UPLOAD_DIR;

init_config() unless -e $CONFIG_FILE;

my $daemon = HTTP::Daemon->new(LocalPort => $PORT) || die "Cannot create HTTP daemon: $!";

print "Enterprise Content System starting on http://localhost:$PORT\n";
print "Server running at: " . $daemon->url . "\n";
print "Available endpoints: /, /login, /download, /upload, /admin/*, /search, /logs\n";

while (my $client = $daemon->accept) {
    while (my $request = $client->get_request) {
        handle_request($client, $request);
    }
    $client->close;
    undef($client);
}

sub init_config {
    my $config = {
        'admin_user' => 'admin',
        'admin_pass' => 'perl123',
        'debug_mode' => 1,
        'allow_eval' => 1,
        'log_level' => 'verbose'
    };

    write_file($CONFIG_FILE, encode_json($config));
}

sub handle_request {
    my ($client, $request) = @_;
    my $method = $request->method;
    my $path = $request->uri->path;
    my $query = $request->uri->query || '';

    log_request($request);

    my $response;

    if ($path eq '/' && $method eq 'GET') {
        $response = handle_home();
    } elsif ($path eq '/login' && $method eq 'POST') {
        $response = handle_login($request);
    } elsif ($path eq '/download' && $method eq 'GET') {
        $response = handle_download($request);
    } elsif ($path eq '/upload' && $method eq 'POST') {
        $response = handle_upload($request);
    } elsif ($path eq '/admin/users' && $method eq 'GET') {
        $response = handle_list_users($request);
    } elsif ($path eq '/admin/process' && $method eq 'POST') {
        $response = handle_process_task($request);
    } elsif ($path eq '/admin/settings' && $method eq 'GET') {
        $response = handle_view_settings($request);
    } elsif ($path eq '/admin/settings' && $method eq 'POST') {
        $response = handle_update_settings($request);
    } elsif ($path eq '/search' && $method eq 'GET') {
        $response = handle_search($request);
    } elsif ($path eq '/logs' && $method eq 'GET') {
        $response = handle_view_logs($request);
    } elsif ($path eq '/admin/archive' && $method eq 'POST') {
        $response = handle_create_archive($request);
    } else {
        $response = HTTP::Response->new(RC_NOT_FOUND, 'Not Found');
        $response->content('<h1>404 Not Found</h1>');
    }

    $response->header('Content-Type', 'text/html') unless $response->header('Content-Type');
    $client->send_response($response);
}

sub handle_home {
    my $response = HTTP::Response->new(RC_OK);
    $response->content(<<'HTML');
<!DOCTYPE html>
<html>
<head><title>Perl File Manager</title></head>
<body>
<h1>Enterprise Content System v4.5</h1>
<h2>Available Endpoints:</h2>
<ul>
<li>POST /login - User authentication (username, password, role params)</li>
<li>GET /download?file=filename - Download files</li>
<li>POST /upload - Upload files (filename, content params)</li>
<li>GET /admin/users?role=admin - List system users</li>
<li>POST /admin/process - Process Perl tasks (role, code params)</li>
<li>GET /admin/settings?role=admin - View system settings</li>
<li>POST /admin/settings - Update system settings (role, setting, value params)</li>
<li>POST /admin/archive - Create data archive (role, source, destination params)</li>
<li>GET /search?pattern=regex - Search files using regex</li>
<li>GET /logs?file=logfile - View log files</li>
</ul>
<h2>Test Login:</h2>
<form method="POST" action="/login">
Username: <input name="username" value="admin"><br>
Password: <input name="password" value="perl123"><br>
Role: <input name="role" value="admin"><br>
<input type="submit" value="Login">
</form>
</body>
</html>
HTML
    return $response;
}

sub handle_login {
    my ($request) = @_;
    my $content = $request->content;
    my %params = parse_form_data($content);

    my $username = $params{username} || '';
    my $password = $params{password} || '';
    my $role = $params{role} || 'user';

    my $config = decode_json(read_file($CONFIG_FILE));

    my $response = HTTP::Response->new(RC_OK);

    if (($username eq $config->{admin_user} && $password eq $config->{admin_pass}) || $role eq 'admin') {
        $response->header('Set-Cookie', "user=$username; role=$role; Path=/");
        $response->content("<h1>Login successful for $username with role $role</h1>");
    } else {
        $response->content('<h1>Login failed</h1>');
    }

    return $response;
}

sub handle_download {
    my ($request) = @_;
    my $file = get_query_param($request, 'file');

    my $response = HTTP::Response->new(RC_OK);

    if (!$file) {
        $response->content('<h1>Error: No file specified</h1>');
        return $response;
    }

    if (-e $file && -r $file) {
        $response->header('Content-Type', 'text/plain');
        $response->content(read_file($file));
    } else {
        $response->content("<h1>File not found or not readable: $file</h1>");
    }

    return $response;
}

sub handle_upload {
    my ($request) = @_;
    my $content = $request->content;
    my %params = parse_form_data($content);

    my $filename = $params{filename};
    my $file_content = $params{content};

    my $response = HTTP::Response->new(RC_OK);

    if (!$filename || !defined $file_content) {
        $response->content('<h1>Error: Missing filename or content</h1>');
        return $response;
    }

    my $filepath = "$UPLOAD_DIR/$filename";

    eval {
        write_file($filepath, $file_content);
        $response->content("<h1>File uploaded successfully to: $filepath</h1>");
    };

    if ($@) {
        $response->content("<h1>Upload failed: $@</h1>");
    }

    return $response;
}

sub handle_list_users {
    my ($request) = @_;
    my $role = get_query_param($request, 'role') || get_cookie($request, 'role') || 'user';

    my $response = HTTP::Response->new(RC_OK);

    if ($role ne 'admin') {
        $response->content('<h1>Access denied - admin role required</h1>');
        return $response;
    }

    if (-e '/etc/passwd') {
        $response->header('Content-Type', 'text/plain');
        $response->content("System Users:\n" . read_file('/etc/passwd'));
    } else {
        $response->content('<h1>System users file not accessible</h1>');
    }

    return $response;
}

sub handle_process_task {
    my ($request) = @_;
    my $content = $request->content;
    my %params = parse_form_data($content);

    my $role = $params{role} || get_cookie($request, 'role') || 'user';
    my $code = $params{code};

    my $response = HTTP::Response->new(RC_OK);

    if ($role ne 'admin') {
        $response->content('<h1>Access denied - admin role required</h1>');
        return $response;
    }

    if (!$code) {
        $response->content('<h1>Error: No code specified</h1>');
        return $response;
    }

    $response->header('Content-Type', 'text/plain');

    my $result = eval $code;
    if ($@) {
        $response->content("Code execution failed:\n$@");
    } else {
        $response->content("Code execution result:\n" . (defined $result ? $result : 'undef'));
    }

    return $response;
}

sub handle_view_settings {
    my ($request) = @_;
    my $role = get_query_param($request, 'role') || get_cookie($request, 'role') || 'user';

    my $response = HTTP::Response->new(RC_OK);

    if ($role ne 'admin') {
        $response->content('<h1>Access denied - admin role required</h1>');
        return $response;
    }

    my $config = read_file($CONFIG_FILE);
    $response->header('Content-Type', 'application/json');
    $response->content($config);

    return $response;
}

sub handle_update_settings {
    my ($request) = @_;
    my $content = $request->content;
    my %params = parse_form_data($content);

    my $role = $params{role} || get_cookie($request, 'role') || 'user';
    my $setting = $params{setting};
    my $value = $params{value};

    my $response = HTTP::Response->new(RC_OK);

    if ($role ne 'admin') {
        $response->content('<h1>Access denied - admin role required</h1>');
        return $response;
    }

    if (!$setting || !defined $value) {
        $response->content('<h1>Error: Missing setting or value</h1>');
        return $response;
    }

    my $config = decode_json(read_file($CONFIG_FILE));
    $config->{$setting} = $value;

    write_file($CONFIG_FILE, encode_json($config));
    $response->content("<h1>Configuration updated: $setting = $value</h1>");

    return $response;
}

sub handle_search {
    my ($request) = @_;
    my $pattern = get_query_param($request, 'pattern');

    my $response = HTTP::Response->new(RC_OK);

    if (!$pattern) {
        $response->content('<h1>Error: No search pattern specified</h1>');
        return $response;
    }

    my $results = '';
    eval {
        if (-d $UPLOAD_DIR) {
            opendir(my $dh, $UPLOAD_DIR);
            while (my $file = readdir($dh)) {
                next if $file =~ /^\./;
                my $filepath = "$UPLOAD_DIR/$file";
                if (-f $filepath) {
                    my $content = read_file($filepath);
                    if ($content =~ /$pattern/m) {
                        $results .= "Match in $filepath:\n";
                        my @lines = split /\n/, $content;
                        foreach my $line (@lines) {
                            if ($line =~ /$pattern/) {
                                $results .= "  $line\n";
                            }
                        }
                        $results .= "\n";
                    }
                }
            }
            closedir($dh);
        }
    };

    if ($@) {
        $results = "Search error: $@";
    }

    $response->header('Content-Type', 'text/plain');
    $response->content("Search Results for pattern: $pattern\n\n$results");

    return $response;
}

sub handle_view_logs {
    my ($request) = @_;
    my $file = get_query_param($request, 'file') || $LOG_FILE;

    my $response = HTTP::Response->new(RC_OK);

    if (-e $file && -r $file) {
        $response->header('Content-Type', 'text/plain');
        $response->content(read_file($file));
    } else {
        $response->content("<h1>Log file not found or not readable: $file</h1>");
    }

    return $response;
}

sub handle_create_archive {
    my ($request) = @_;
    my $content = $request->content;
    my %params = parse_form_data($content);

    my $role = $params{role} || get_cookie($request, 'role') || 'user';
    my $source = $params{source} || '/etc/passwd';
    my $destination = $params{destination} || '/tmp/backup.tar.gz';

    my $response = HTTP::Response->new(RC_OK);

    if ($role ne 'admin') {
        $response->content('<h1>Access denied - admin role required</h1>');
        return $response;
    }

    my $command = "tar -czf $destination $source $CONFIG_FILE $LOG_FILE";

    $response->header('Content-Type', 'text/plain');
    $response->content("Backup command: $command\n\n");

    my $result = `$command 2>&1`;
    $response->content($response->content . "Result:\n$result");

    return $response;
}

sub parse_form_data {
    my ($data) = @_;
    my %params;

    return %params unless $data;

    foreach my $pair (split /&/, $data) {
        my ($key, $value) = split /=/, $pair, 2;
        $key = uri_unescape($key) if $key;
        $value = uri_unescape($value) if defined $value;
        $params{$key} = $value if $key;
    }

    return %params;
}

sub get_query_param {
    my ($request, $param) = @_;
    my $query = $request->uri->query || '';

    foreach my $pair (split /&/, $query) {
        my ($key, $value) = split /=/, $pair, 2;
        return uri_unescape($value) if $key eq $param && defined $value;
    }

    return undef;
}

sub get_cookie {
    my ($request, $name) = @_;
    my $cookie_header = $request->header('Cookie') || '';

    foreach my $cookie (split /;\s*/, $cookie_header) {
        my ($key, $value) = split /=/, $cookie, 2;
        return $value if $key eq $name && defined $value;
    }

    return undef;
}

sub log_request {
    my ($request) = @_;
    my $timestamp = localtime();
    my $method = $request->method;
    my $uri = $request->uri;
    my $log_entry = "[$timestamp] $method $uri\n";

    open my $fh, '>>', $LOG_FILE;
    print $fh $log_entry;
    close $fh;
}