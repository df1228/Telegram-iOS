# https://just.systems/man/zh/chapter_27.html
# https://just.systems/man/zh/chapter_32.html
# https://just.systems/man/zh/chapter_44.html
# https://just.systems/man/zh/chapter_42.html
# https://docs.cloudbees.com/docs/cloudbees-ci-kb/latest/client-and-managed-masters/how-to-ignore-failures-in-a-shell-step

OUTPUT_PATH := "build/artifacts"
BAZEL_USER_ROOT         := "/private/var/tmp/_bazel_"
GIT_COMMIT_COUNT        := `git rev-list HEAD --count`
BUILD_NUMBER_OFFSET     :=`cat build_number_offset`
BUILD_NUMBER            := GIT_COMMIT_COUNT + BUILD_NUMBER_OFFSET

default:
    just -l

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

bash-test:
    #!/usr/bin/env bash
    set -euxo pipefail
    hello='Yo'
    echo "$hello from bash!"

upload:
    rsync -avP -e "ssh -i $HOME/.ssh/aws.pem" \
        --include-from=.includes.txt --exclude-from=.excludes.txt . \
        ec2-user@ec2-52-23-254-127.compute-1.amazonaws.com:~/tmp/Telegram-iOS/

build MODE='debug_universal':
    #! /bin/bash
    set -xeuo pipefail
    python3 -u build-system/Make/Make.py \
        --bazelUserRoot="{{BAZEL_USER_ROOT}}" \
        build \
        --configurationPath="build-system/development-configuration.json" \
        --codesigningInformationPath=build-system/dev-codesigning \
        --configuration={{MODE}} \
        --buildNumber={{BUILD_NUMBER}}

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

build-release:
    #! /bin/bash
    set -xeuo pipefail
    python3 -u build-system/Make/Make.py \
        --bazelUserRoot="{{BAZEL_USER_ROOT}}" \
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
        --configurationPath="build-system/development-configuration.json" \
        --codesigningInformationPath=build-system/dev-codesigning \
        --disableExtensions

collect-ipa:
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