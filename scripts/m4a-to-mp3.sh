#!/bin/bash
IN=$1
OUT=$2
ffmpeg "${OUT}" -i "${IN}" -codec:a libmp3lame -qscale:a 1
