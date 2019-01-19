#!/bin/bash

COMMIT=$1

if [ -z $COMMIT]; then exit; fi

cd $SUBJECT && git checkout $COMMIT && git diff -U0 HEAD^ HEAD > $TMP_DIR/commit.diff

cat $TMP_DIR/commit.diff | $TMP_DIR/showlinenum.awk show_header=0 path=1 | grep -e "\.[ch]:[0-9]*:+" -e "\.cpp:[0-9]*:+" -e "\.cc:[0-9]*:+" | cut -d+ -f1 | rev | cut -c2- | rev > $TMP_DIR/BBtargets.txt

echo "Targets:" && cat $TMP_DIR/BBtargets.txt

# RUN libtoolize && aclocal && autoheader && autoconf && automake --add-missing

cd $SUBJECT && ./autogen.sh && ./configure --disable-shared && make -j$(nproc) clean && make -j$(nproc) all

$SUBJECT/xmllint --valid --recover $SUBJECT/test/dtd3

ls $TMP_DIR/dot-files

echo "Function targets" && cat $TMP_DIR/Ftargets.txt

# Clean up
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt

# Generate distance
$AFLGO/scripts/genDistance.sh $SUBJECT $TMP_DIR xmllint

# Check distance file
echo "Distance values:" && head -n5 $TMP_DIR/distance.cfg.txt
tail -n5 $TMP_DIR/distance.cfg.txt
export CFLAGS="$COPY_CFLAGS -distance=$TMP_DIR/distance.cfg.txt"
export CXXFLAGS="$COPY_CXXFLAGS -distance=$TMP_DIR/distance.cfg.txt"

# Clean and build subject with distance instrumentation
cd $SUBJECT && make clean && ./configure --disable-shared && make -j$(nproc) all

mkdir -p $RUN_DIR

cp $SUBJECT/test/dtd* $RUN_DIR
cp $SUBJECT/test/dtds/* $RUN_DIR

$AFLGO/afl-fuzz -S $COMMIT -z exp -c 45m -i $RUN_DIR -o out $SUBJECT/xmllint --valid --recover @@
