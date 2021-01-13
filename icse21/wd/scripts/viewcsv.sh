#!/bin/bash

cat "${1:--}" | column -n -t -s, | less -S
