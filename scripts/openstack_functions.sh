CATALOG=${CATALOG:-$(pwd)/.catalog.json}

function auth(){
    RESP=$(curl -iqs https://auth.cloud.ovh.net/v3/auth/tokens \
         -X POST \
         -d '{ "auth": { "identity": { "methods": [ "password" ], "password": { "user": { "name": "'$OS_USERNAME'", "domain": { "name": "default" }, "password": "'$OS_PASSWORD'" } } } } }' \
         -H "Content-type: application/json")

    # output token's catalog in './.catalog.json'
    echo $RESP | awk -v RS='\r' '/"catalog"/ {print}' | jq '.token.catalog' > $CATALOG

    # echo token
    echo $RESP | awk -v RS='\r' '/X-Subject-Token: /{print $2}'
}

function image_catalog_url(){
    cat $CATALOG | jq -r '.[]|select(.type == "image")|.endpoints[]|select(.interface== "public" and .region == "'$OS_REGION_NAME'").url'
}

function image_url(){
    local name=$1
    local version=$2
    local version_selector=""
    if [ ! -z "$version" ]; then
        version_selector='and .version == "'$version'"'
    fi

    image_catalog_url=$(cat $CATALOG | jq -r '.[]|select(.type == "image")|.endpoints[]|select(.interface== "public" and .region == "'$OS_REGION_NAME'").url')
    uri="$(curl -qs -H "X-Auth-Token: ${OS_TOKEN}" "${image_catalog_url}/v2/images" | jq -r '.images|sort_by(.created_at)|.[]|select(.name == "'"$name"'" and .image_state == "available" '$version_selector')|.file' | tail -1)"
    if [ ! -z "$uri" ]; then
        echo ${image_catalog_url}${uri}
    else
        return 1
    fi
}

function network_id(){
    network_base_url=$(cat $CATALOG | jq -r '.[]|select(.type == "network")|.endpoints[]|select(.interface== "public" and .region == "'$OS_REGION_NAME'").url')
    curl -qs -H "X-Auth-Token: ${OS_TOKEN}" "${network_base_url}/v2.0/networks?name=Ext-Net&shared=true&status=ACTIVE" | jq -r '.networks[].id' | tail -1
}
