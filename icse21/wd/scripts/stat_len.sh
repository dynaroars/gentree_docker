#!/bin/bash

set -e

PREFIX=res/Analyze/stat_len

analyze(){
	NAME=$1
	./gt -A0 -T5 -GF 2/$NAME -I res/$NAME/full.txt -P $PREFIX/$NAME.csv
}
analyze_nf(){
	NAME=$1
	./gt -A0 -T5 -GF 2/$NAME -I res/$NAME/a_0.txt -P $PREFIX/$NAME.csv
}

mkdir -p $PREFIX

analyze id
analyze uname
analyze cat
analyze mv
analyze ln
analyze date
analyze join

analyze    sort
analyze_nf ls


analyze    grin
analyze_nf pylint
analyze_nf unison
analyze_nf bibtex2html


analyze_nf vsftpd
analyze    ngircd
