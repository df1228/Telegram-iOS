OUTPUT_PATH := "build/artifacts"
BAZEL_USER_ROOT := "/private/var/tmp/_bazel_"                                                         

default:
    echo 'Hello, world!'

upload:
    rsync -avP -e "ssh -i $HOME/.ssh/aws.pem" \
        --include-from=.includes.txt --exclude-from=.excludes.txt . \
        ec2-user@ec2-52-23-254-127.compute-1.amazonaws.com:~/tmp/Telegram-iOS/

build:
    #! /bin/bash
    set -xeuo pipefail
    python3 -u build-system/Make/Make.py \
    --bazelUserRoot="{{BAZEL_USER_ROOT}}" \
    build \
    --configurationPath="build-system/development-configuration.json" \
    --codesigningInformationPath=build-system/dev-codesigning \
    --configuration=debug_universal \
    --buildNumber=111111

build-release:
    #! /bin/bash
    set -xeuo pipefail
    python3 -u build-system/Make/Make.py \
    --bazelUserRoot="{{BAZEL_USER_ROOT}}" \
    build \
    --configurationPath="build-system/development-configuration.json" \
    --codesigningInformationPath=build-system/dev-codesigning \
    --configuration=release_universal \
    --buildNumber=111111

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