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