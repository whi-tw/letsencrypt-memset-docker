#!/usr/bin/env bash
function _debug() {
  if [[ $DEBUG ]]
  then
    echo " ++ $*"
  fi
}

function _info() {
  echo " + $*"
}

function _memset_get {
  local URL="${1}"
  curl -s -X GET "https://$MEMSET_KEY:x@api.memset.com/v1/json/$URL" -H "Content-Type: application/json"
}

function _check_DNS {
  local NAME="${1}"
  dig +short TXT $NAME @8.8.8.8 | sed 's/"//g'
}

# https://www.memset.com/apidocs/methods_dns.html#dns.zone_domain_list
function _get_zone_id {
  local DOMAIN="${1}"
  len=$(($(echo $DOMAIN | tr '.' ' ' | wc -w)-1))
  for i in $(seq $len)
  do
    result=$(_memset_get "dns.zone_domain_list")
    id=$(echo $result | jq -r ".[] | select(.domain==\"$DOMAIN\").zone_id")
    if [ "$id" != "" ]
    then
      echo $id
      return
    fi
    DOMAIN=$(echo $DOMAIN | cut -d "." -f 2-)
  done
}

# https://www.memset.com/apidocs/methods_dns.html#dns.zone_domain_list
function _get_bare_domain {
  local DOMAIN="${1}"
  len=$(($(echo $DOMAIN | tr '.' ' ' | wc -w)-1))
  for i in $(seq $len)
  do
    result=$(_memset_get "dns.zone_domain_list")
    id=$(echo $result | jq -r ".[] | select(.domain==\"$DOMAIN\").zone_id")
    if [ "$id" != "" ]
    then
      echo $DOMAIN
      return
    fi
    DOMAIN=$(echo $DOMAIN | cut -d "." -f 2-)
  done
}

# https://www.memset.com/apidocs/methods_dns.html#dns.zone_info
function _get_txt_record_id {
  local ZONE_ID="${1}" NAME="${2}" TOKEN="${3}"
  result=$(_memset_get "dns.zone_info?id=$ZONE_ID")
  echo $result | jq -r ".records[] | select(.type==\"TXT\") | select(.record==\"$NAME\") | select(.address==\"$TOKEN\").id"
}

# https://www.memset.com/apidocs/methods_dns.html#dns.zone_record_create
function deploy_challenge {
  local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"
  _debug "Creating Challenge: $1: $3"
  ZONE_ID=$(_get_zone_id $DOMAIN)
  BARE_DOMAIN=$(_get_bare_domain $DOMAIN)
  _debug "Got Zone ID $ZONE_ID"
  FQDN="_acme-challenge.$DOMAIN"
  NAME=$(echo "$FQDN" | sed "s/.$BARE_DOMAIN//")
  result=$(_memset_get "dns.zone_record_create?zone_id=$ZONE_ID&type=TXT&record=$NAME&address=$TOKEN_VALUE&ttl=0")
  RECORD_ID=$(echo $result | jq -r '.id')
  _debug "TXT record created, ID: $RECORD_ID"
  reload=$(_memset_get 'dns.reload')
  RELOAD_ID=$(echo $reload | jq -r '.id')
  _debug "Reload job started with ID: $RELOAD_ID"
  _info "Waiting 10s for DNS reload to complete...."
  sleep 10

  while [ $(_memset_get "job.status?id=$RELOAD_ID" | jq '.finished') == false ]
  do
    _info "Reload not complete. Waiting another 10s...."
    sleep 10
  done

  _info "DNS Reload completed. Checking for propagation..."

  while [ "$(_check_DNS $FQDN)" != "$TOKEN_VALUE" ]
  do
    _debug "\"$(_check_DNS $FQDN)\" != \"$TOKEN_VALUE\""
    _info "DNS not propagated, waiting 30s..."
    sleep 30
  done

}

# https://www.memset.com/apidocs/methods_dns.html#dns.zone_record_delete
function clean_challenge {
  local DOMAIN="${1}" TOKEN="${3}"

  if [ -z "$DOMAIN" ]
  then
    _info "http_request() error in letsencrypt.sh?"
    return
  fi

  ZONE_ID=$(_get_zone_id $DOMAIN)
  _debug "Got Zone ID $ZONE_ID"
  BARE_DOMAIN=$(_get_bare_domain $DOMAIN)
  NAME=$(echo "_acme-challenge.$DOMAIN" | sed "s/.$BARE_DOMAIN//")
  RECORD_ID=$(_get_txt_record_id $ZONE_ID $NAME $TOKEN)
  _debug "Deleting TXT record, ID: $RECORD_ID"

  result=$(_memset_get "dns.zone_record_delete?id=$RECORD_ID")
}

function deploy_cert {
  local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}" TIMESTAMP="${6}"
  _info "ssl_certificate: $CERTFILE"
  _info "ssl_certificate_key: $KEYFILE"
}

function unchanged_cert {
  return
}

# check environmental vars
[ -z "$MEMSET_KEY" ] && echo "Need to set MEMSET_KEY" && exit 1

HANDLER=$1; shift; $HANDLER $@
