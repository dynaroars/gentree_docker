#!/bin/bash

set -e

run(){
	NAME=$1
	mkdir -p res/$NAME
	rm -rf 2/$NAME.cachedb
	./gt -J2 -crwx -GF 2/$NAME --rep 11 -O res/$NAME/a_{i}.txt -j64 --rep-para 11
	./gt -J2 -crwx -GF 2/$NAME          -O res/$NAME/full.txt --full -j64
}

run id
run uname
run cat
run mv
run ln
run date
run join
