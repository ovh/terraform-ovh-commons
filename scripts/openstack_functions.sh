BASEDIR=$(dirname $0)
CATALOG=$BASEDIR/.catalog.json

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

function image_url(){
    image_base_url=$(cat $CATALOG | jq -r '.[]|select(.type == "image")|.endpoints[]|select(.interface== "public" and .region == "'$OS_REGION_NAME'").url')
    echo ${image_base_url}/$(curl -qs -H "X-Auth-Token: ${OS_TOKEN}" "${image_base_url}/v2/images" | jq -r '.images|sort_by(.created_at)|.[]|select(.name == "'"$IMAGE_NAME"'" and .image_state == "available")|.file' | tail -1)
}

function network_id(){
    network_base_url=$(cat $CATALOG | jq -r '.[]|select(.type == "network")|.endpoints[]|select(.interface== "public" and .region == "'$OS_REGION_NAME'").url')
    curl -qs -H "X-Auth-Token: ${OS_TOKEN}" "${network_base_url}/v2.0/networks?name=Ext-Net&shared=true&status=ACTIVE" | jq -r '.networks[].id' | tail -1
}
