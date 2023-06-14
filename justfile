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
    mkdir -p build/artifacts/
    chmod -R 777 build/artifacts/

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

build MODE='debug_universal':
    #! /bin/bash
    set -xeuo pipefail
    python3 -u build-system/Make/Make.py \
        --bazelUserRoot="{{BAZEL_USER_ROOT_DEBUG}}" \
        build \
        --configurationPath="build-system/dev-configuration.json" \
        --codesigningInformationPath=build-system/dev-codesigning \
        --configuration={{MODE}} \
        --buildNumber={{BUILD_NUMBER}}

build-release: prepare
    #! /bin/bash
    set -xeuo pipefail
    python3 -u build-system/Make/Make.py \
        --bazelUserRoot="{{BAZEL_USER_ROOT_RELEASE}}" \
        build \
        --configurationPath="build-system/prod-configuration.json" \
        --codesigningInformationPath=build-system/prod-codesigning \
        --configuration=release_universal \
        --buildNumber={{BUILD_NUMBER}}
    for f in bazel-out/applebin_ios-ios_arm*-opt-ST-*/bin/Telegram/Telegram.ipa; do
        cp "$f" {{OUTPUT_PATH}}/
    done
    cp -f {{OUTPUT_PATH}}/Telegram.ipa /tmp/Telegram-release-$(date +"%Y%m%d%H%M%S").ipa

gen:
    #! /bin/bash
    set -xeuo pipefail
    python3 build-system/Make/Make.py \
        --cacheDir="$HOME/telegram-bazel-cache" \
        generateProject \
        --configurationPath="build-system/dev-configuration.json" \
        --codesigningInformationPath=build-system/dev-codesigning \
        --disableExtensions

collect-ipa: prepare
    #! /bin/bash
    set -xeuo pipefail
    rm -rf "{{OUTPUT_PATH}}"
    mkdir -p "{{OUTPUT_PATH}}"
    for f in bazel-out/applebin_ios-ios_arm*-opt-ST-*/bin/Telegram/Telegram.ipa; do
        cp "$f" {{OUTPUT_PATH}}/
    done
    cp {{OUTPUT_PATH}}/Telegram.ipa /tmp/Telegram-$(date +"%Y%m%d%H%M%S").ipa
    cp {{OUTPUT_PATH}}/Telegram.ipa /Users/Shared/telegram-ios/build/artifacts/Telegram.ipa

download-ipa:
    rsync -rvP mac:/Users/Shared/Telegram-iOS/build/artifacts/Telegram.ipa /tmp/Telegram-release-$(date +"%Y%m%d").ipa

clean:
    python3 -u build-system/Make/Make.py clean

upload-ipa:
    #! /bin/bash
    set -xeuo pipefail
    mkdir -p ~/.appstoreconnect/private_keys
    echo -n "$PRIVATE_API_KEY_BASE64" | base64 --decode -o ~/.appstoreconnect/private_keys/AuthKey_$API_KEY.p8
    xcrun altool --output-format xml --upload-app -f /Users/Shared/Telegram-iOS/build/artifacts/Telegram.ipa -t ios --apiKey $API_KEY --apiIssuer $API_ISSUER

alias tf := release-ipa
release-ipa: build-release && upload-ipa
    echo "uploaded to testflight, please wait for processing"

validate-ipa:
    xcrun altool --validate-app -f /Users/Shared/Telegram-iOS/build/artifacts/Telegram.ipa -t ios --apiKey $API_KEY --apiIssuer $API_ISSUER