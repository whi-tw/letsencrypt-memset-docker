## Synopsis

A docker container which handles letsencrypt certificate creation and renewal. Also on [Docker Hub](https://hub.docker.com/r/tnwhitwell/letsencrypt.sh-memset/ "Docker Hub")

## Code Example

Should be run with:

    docker run --rm -it \
    --name="letsencrypt.sh" \
    -e MEMSET_KEY='<MEMSET_KEY>' \
    -v letsencrypt.sh/accounts:/letsencrypt.sh/accounts \
    -v letsencrypt.sh/certs:/letsencrypt.sh/certs \
    -v letsencrypt.sh/domains.txt:/letsencrypt.sh/domains.txt:ro \
    tnwhitwell/letsencrypt.sh-cloudflare

The mapped volumes (/letsencrypt.sh/accounts, /letsencrypt.sh/certs, /letsencrypt.sh/domains.txt) should be mapped somewhere static. The certificates will be created in the /certs folder.

## Memset API Key requirements

The key should have access to at least:
 - job.status
 - dns.reload
 - dns.zone_domain_list
 - dns.zone_info
 - dns.zone_record_create
 - dns.zone_record_delete

This can be set up when logged in via: https://www.memset.com/control/api/keys/

## Installation

    git clone https://github.com/tnwhitwell/letsencrypt-memset-docker
    cd letsencrypt-memset-docker
    cp run.sh.example run.sh

open run.sh in an editor
edit "<MEMSET_KEY>" to match the API key you set up with Memset

    cp domains.txt.example domains.txt

open domains.txt in an editor
enter domains, one line per certificate, with SAN names as per:

    example.com alternate.com subdomain.example.com
    anothercert.com test.anothercert.com
<!-- break -->

    ./run.sh



## Credits

Dig for Alpine:
https://github.com/sequenceiq/docker-alpine-dig/
