# Copyright (C) Extensible Service Proxy Authors
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
################################################################################
#
use strict;
use warnings;

################################################################################

use src::nginx::t::ApiManager;   # Must be first (sets up import path to the Nginx test module)
use Test::Nginx;  # Imports Nginx's test module
use Test::More;   # And the test framework

################################################################################

# Port assignments
my $Http2NginxPort = ApiManager::pick_port();

my $t = Test::Nginx->new()->has(qw/http proxy/)->plan(2);

# This service config doesn't configure backend addresses
$t->write_file(
    'service.pb.txt',
    ApiManager::get_bookstore_service_config_allow_all_http_requests);

$t->write_file_expand('nginx.conf', <<"EOF");
%%TEST_GLOBALS%%
daemon off;
events {
  worker_connections 32;
}
http {
  %%TEST_GLOBALS_HTTP%%
  server {
    listen 127.0.0.1:${Http2NginxPort} http2;
    server_name localhost;
    location / {
      endpoints {
        api service.pb.txt;
        service_control off;
        on;
      }
      grpc_pass;
    }
  }
}
EOF

$t->run();
is($t->waitforsocket("127.0.0.1:${Http2NginxPort}"), 1, 'Nginx socket ready.');

################################################################################
my $test_results = &ApiManager::run_grpc_test($t, <<"EOF");
server_addr: "127.0.0.1:${Http2NginxPort}"
plans {
  echo {
    request {
      text: "Hello, world!"
    }
  }
}
EOF

$t->stop_daemons();

my $test_results_expected = <<'EOF';
results {
  status {
    code: 5
    details: "No GRPC backend address specified"
  }
}
EOF

is($test_results, $test_results_expected, 'Client tests completed as expected.');

################################################################################

