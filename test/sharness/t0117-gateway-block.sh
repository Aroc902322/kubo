#!/usr/bin/env bash

test_description="Test HTTP Gateway Raw Block (application/vnd.ipld.raw) Support"

. lib/test-lib.sh

test_init_ipfs
test_launch_ipfs_daemon_without_network

# Import test case
# See the static fixtures in ./t0117-gateway-block/
test_expect_success "Add the dir test directory" '
  ipfs dag import --pin-roots ../t0117-gateway-block/fixtures.car
'
ROOT_DIR_CID=bafybeie72edlprgtlwwctzljf6gkn2wnlrddqjbkxo3jomh4n7omwblxly # ./
FILE_CID=bafkreihhpc5y2pqvl5rbe5uuyhqjouybfs3rvlmisccgzue2kkt5zq6upq # ./dir/ascii.txt

# GET unixfs dir root block and compare it with `ipfs block get` output

    test_expect_success "GET with format=raw param returns a raw block" '
    ipfs block get "/ipfs/$ROOT_DIR_CID/dir" > expected &&
    curl -sX GET "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT_DIR_CID/dir?format=raw" -o curl_ipfs_dir_block_param_output &&
    test_cmp expected curl_ipfs_dir_block_param_output
    '

    test_expect_success "GET for application/vnd.ipld.raw returns a raw block" '
    ipfs block get "/ipfs/$ROOT_DIR_CID/dir" > expected_block &&
    curl -sX GET -H "Accept: application/vnd.ipld.raw" "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT_DIR_CID/dir" -o curl_ipfs_dir_block_accept_output &&
    test_cmp expected_block curl_ipfs_dir_block_accept_output
    '

    test_expect_success "GET for application/vnd.ipld.raw with single range request includes correct bytes" '
    echo -n "application" > expected_file_block_single_range &&
    curl -sX GET -H "Accept: application/vnd.ipld.raw" -H "Range: bytes=6-16" "http://127.0.0.1:$GWAY_PORT/ipfs/$FILE_CID" -o curl_ipfs_file_block_single_range &&
    test_cmp expected_file_block_single_range curl_ipfs_file_block_single_range
    '

    test_expect_success "GET for application/vnd.ipld.raw with multiple range request includes correct bytes" '
    curl -sX GET -H "Accept: application/vnd.ipld.raw" -H "Range: bytes=6-16,0-4" "http://127.0.0.1:$GWAY_PORT/ipfs/$FILE_CID" -o curl_ipfs_file_block_multiple_range &&
    test_should_contain "Content-Range: bytes 6-16/31" curl_ipfs_file_block_multiple_range &&
    test_should_contain "Content-Type: application/vnd.ipld.raw" curl_ipfs_file_block_multiple_range &&
    test_should_contain "application" curl_ipfs_file_block_multiple_range &&
    test_should_contain "Content-Range: bytes 0-4/31" curl_ipfs_file_block_multiple_range &&
    test_should_contain "hello" curl_ipfs_file_block_multiple_range
    '

# Make sure expected HTTP headers are returned with the block bytes

    test_expect_success "GET response for application/vnd.ipld.raw has expected Content-Type" '
    curl -svX GET -H "Accept: application/vnd.ipld.raw" "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT_DIR_CID/dir/ascii.txt" >/dev/null 2>curl_output &&
    test_should_contain "< Content-Type: application/vnd.ipld.raw" curl_output
    '

    test_expect_success "GET response for application/vnd.ipld.raw includes Content-Length" '
    BYTES=$(ipfs block get $FILE_CID | wc --bytes)
    test_should_contain "< Content-Length: $BYTES" curl_output
    '

    test_expect_success "GET response for application/vnd.ipld.raw includes Content-Disposition" '
    test_should_contain "< Content-Disposition: attachment\; filename=\"${FILE_CID}.bin\"" curl_output
    '

    test_expect_success "GET response for application/vnd.ipld.raw includes nosniff hint" '
    test_should_contain "< X-Content-Type-Options: nosniff" curl_output
    '

    test_expect_success "GET for application/vnd.ipld.raw with query filename includes Content-Disposition with custom filename" '
    curl -svX GET -H "Accept: application/vnd.ipld.raw" "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT_DIR_CID/dir/ascii.txt?filename=foobar.bin" >/dev/null 2>curl_output_filename &&
    test_should_contain "< Content-Disposition: attachment\; filename=\"foobar.bin\"" curl_output_filename
    '

# Cache control HTTP headers
# (basic checks, detailed behavior is tested in  t0116-gateway-cache.sh)

    test_expect_success "GET response for application/vnd.ipld.raw includes Etag" '
    test_should_contain "< Etag: \"${FILE_CID}.raw\"" curl_output
    '

    test_expect_success "GET response for application/vnd.ipld.raw includes X-Ipfs-Path and X-Ipfs-Roots" '
    test_should_contain "< X-Ipfs-Path" curl_output &&
    test_should_contain "< X-Ipfs-Roots" curl_output
    '

    test_expect_success "GET response for application/vnd.ipld.raw includes Cache-Control" '
    test_should_contain "< Cache-Control: public, max-age=29030400, immutable" curl_output
    '

test_kill_ipfs_daemon

test_done
