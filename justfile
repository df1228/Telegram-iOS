# https://just.systems/man/zh/chapter_27.html
# https://just.systems/man/zh/chapter_32.html
# https://just.systems/man/zh/chapter_44.html
# https://just.systems/man/zh/chapter_42.html
# https://docs.cloudbees.com/docs/cloudbees-ci-kb/latest/client-and-managed-masters/how-to-ignore-failures-in-a-shell-step

# https://superuser.com/questions/214004/how-to-add-user-to-a-group-from-mac-os-x-command-line
# sudo dseditgroup -o edit -a ec2-user -t user admin
# sudo dseditgroup -o edit -a ec2-user -t user wheel
# sudo chmod 777 /private/var/tmp/_bazel_for_debug

OUTPUT_PATH                     := "build/artifacts"
BAZEL_USER_ROOT_DEBUG           := "/private/var/tmp/_bazel_for_debug"
BAZEL_USER_ROOT_RELEASE         := "/private/var/tmp/_bazel_for_release"
GIT_COMMIT_COUNT                := `git rev-list HEAD --count`
BUILD_NUMBER_OFFSET             :=`cat build_number_offset`
BUILD_NUMBER                    := BUILD_NUMBER_OFFSET + GIT_COMMIT_COUNT
SHORT_SHA                       := `git rev-parse --short HEAD`

set dotenv-load := true

default:
    @just -l

print:
    #!/usr/bin/env bash
    set -euxo pipefail
    echo 'Hello, world!'
    sha=`git rev-parse --short HEAD`
    echo "shortsha is: $sha"
    echo $sha
    echo {{GIT_COMMIT_COUNT}}
    echo {{BUILD_NUMBER_OFFSET}}
    echo {{BUILD_NUMBER}}

prepare:
    mkdir -p /Users/Shared/build/artifacts
    chmod -R 777 /Users/Shared/build/artifacts

bash-test:
    #!/usr/bin/env bash
    set -euxo pipefail
    hello='Yo'
    echo "$hello from bash!"

rebuild-keychain-dev:
    #! /bin/bash
    set +e
    set -x
    echo "rebuild keychain for dev"
    security delete-keychain ~/Library/Keychains/temp.keychain-db
    python3 build-system/Make/ImportCertificates.py --path build-system/dev-codesigning/certs

rebuild-keychain-prod:
    #! /bin/bash
    set +e
    security delete-keychain ~/Library/Keychains/temp.keychain-db
    python3 build-system/Make/ImportCertificates.py --path build-system/prod-codesigning/certs

build MODE='debug_universal': rebuild-keychain-prod
    #! /bin/bash
    set -xeuo pipefail
    python3 -u build-system/Make/Make.py \
        --bazelUserRoot="{{BAZEL_USER_ROOT_DEBUG}}" \
        build \
        --configurationPath="build-system/prod-configuration.json" \
        --codesigningInformationPath=build-system/prod-codesigning \
        --configuration={{MODE}} \
        --buildNumber={{BUILD_NUMBER}}

build-release: prepare rebuild-keychain-prod && notify-telegram
    #! /bin/bash
    set -xeuo pipefail
    python3 -u build-system/Make/Make.py \
        --bazelUserRoot="{{BAZEL_USER_ROOT_RELEASE}}" \
        build \
        --configurationPath="build-system/prod-configuration.json" \
        --codesigningInformationPath=build-system/prod-codesigning \
        --configuration=release_universal \
        --buildNumber={{BUILD_NUMBER}}
    mkdir -p {{OUTPUT_PATH}}
    chmod -R 777 build/artifacts/
    for f in bazel-out/applebin_ios-ios_arm*-opt-ST-*/bin/Telegram/Telegram.ipa; do
        cp -f "$f" {{OUTPUT_PATH}}/
    done

gen:
    #! /bin/bash
    set -xeuo pipefail
    python3 build-system/Make/Make.py \
        --bazelUserRoot="{{BAZEL_USER_ROOT_DEBUG}}" \
        generateProject \
        --configurationPath="build-system/prod-configuration.json" \
        --codesigningInformationPath=build-system/prod-codesigning \
        --disableExtensions

collect-ipa: prepare
    #! /bin/bash
    set +e
    set -x
    mkdir -p "{{OUTPUT_PATH}}"
    chmod -R 777 build/artifacts/
    for f in bazel-out/applebin_ios-ios_arm*-opt-ST-*/bin/Telegram/Telegram.ipa; do
        cp -f "$f" {{OUTPUT_PATH}}/
    done
    cp -f {{OUTPUT_PATH}}/Telegram.ipa /Users/Shared/build/artifacts/Telegram.ipa
    cp -f {{OUTPUT_PATH}}/Telegram.ipa /Users/Shared/build/artifacts/Telegram-{{SHORT_SHA}}.ipa


collect-debug-ipa: prepare
    #! /bin/bash
    set +e
    set -x
    mkdir -p "{{OUTPUT_PATH}}"
    chmod -R 777 build/artifacts/
    for f in bazel-out/applebin_ios-ios_arm*-dbg-ST-*/bin/Telegram/Telegram.ipa; do
        cp -f "$f" {{OUTPUT_PATH}}/
    done
    cp -f {{OUTPUT_PATH}}/Telegram.ipa /Users/Shared/build/artifacts/Telegram.ipa
    cp -f {{OUTPUT_PATH}}/Telegram.ipa /Users/Shared/build/artifacts/Telegram-{{SHORT_SHA}}.ipa

download-ipa:
    rsync -rvP mac:/Users/Shared/build/artifacts/Telegram.ipa /tmp/Telegram.ipa

clean:
    python3 -u build-system/Make/Make.py clean
    rm -rf build-input bazel-*
    git submodule update --recursive

upload-ipa: collect-ipa
    #! /bin/bash
    set -xeuo pipefail
    mkdir -p ~/.appstoreconnect/private_keys
    echo -n "$PRIVATE_API_KEY_BASE64" | base64 --decode -o ~/.appstoreconnect/private_keys/AuthKey_$API_KEY.p8
    xcrun altool --output-format xml --upload-app -f /Users/Shared/build/artifacts/Telegram.ipa -t ios --apiKey $API_KEY --apiIssuer $API_ISSUER

alias tf := release-ipa
release-ipa: build-release && upload-ipa
    echo "uploaded to testflight, please wait for processing"

validate-ipa:
    xcrun altool --validate-app -f /Users/Shared/build/artifacts/Telegram.ipa -t ios --apiKey $API_KEY --apiIssuer $API_ISSUER


notify-telegram:
    #! /bin/bash
    set -xeuo pipefail
    curl -X POST \
        -H 'Content-Type: application/json' \
        -d '{"chat_id": "363420688", "text": "notification from justfile !!!!", "disable_notification": false}' \
        https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage

deploy-ipa-to-ota-server: collect-ipa && notify-telegram
    #! /bin/bash
    set -xeuo pipefail
    # eval `ssh-agent`
    # ssh-add ~/.ssh/aws.pem
    # rsync -vP /Users/Shared/build/artifacts/Telegram.ipa root@49.234.96.230:/var/www/html/ota
    cos cp /Users/Shared/build/artifacts/Telegram.ipa cos://ota-1312624471/