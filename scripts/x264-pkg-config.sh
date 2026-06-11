#!/bin/zsh
set -euo pipefail

for argument in "$@"; do
    case "$argument" in
        --version)
            echo "LoopForge x264 adapter 1.0"
            exit 0
            ;;
    esac
done

if [[ -z "${X264_PREFIX:-}" ]] || [[ " $* " != *" x264 "* ]]; then
    exit 1
fi

for argument in "$@"; do
    case "$argument" in
        --exists|--atleast-version=*|--exact-version=*|--max-version=*)
            ;;
        --modversion)
            echo "0.164"
            exit 0
            ;;
        --cflags)
            echo "-I$X264_PREFIX/include"
            exit 0
            ;;
        --cflags-only-I)
            echo "-I$X264_PREFIX/include"
            exit 0
            ;;
        --libs)
            echo "-L$X264_PREFIX/lib -lx264 -lpthread -lm"
            exit 0
            ;;
        --variable=prefix|--variable=includedir)
            if [[ "$argument" == "--variable=includedir" ]]; then
                echo "$X264_PREFIX/include"
            else
                echo "$X264_PREFIX"
            fi
            exit 0
            ;;
    esac
done

exit 0
