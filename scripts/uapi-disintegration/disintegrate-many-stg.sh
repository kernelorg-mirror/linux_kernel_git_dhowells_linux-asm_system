#!/bin/sh -x

UAPI=uapi
export UAPI

###############################################################################
#
#
#
###############################################################################
stg ref
if stg id begin-marker >&/dev/null
then
    stg del begin-marker.. || exit $?
fi

stg new begin-marker -m "Begin userspace API extraction" || exit $?

# function set_up_uapi_dir () {
#     if [ -d $1 ]
#     then
# 	rm -r $1 || exit $?
#     fi
#     mkdir -p $1 || exit $?
# }
# set_up_uapi_dir $UAPI/linux
# set_up_uapi_dir arch/mn10300/$UAPI/asm

{
    ./disintegrate/uapi/genlist.pl
    #grep -rIl __KERNEL__ include/linux/[ab]*.h
    #echo include/linux/acct.h
    #echo include/linux/const.h
    #echo arch/mn10300/include/asm/ioctl.h
    #echo include/linux/types.h
} |
while read f
do
    if [ ! -f $f ]
    then
	continue
    fi

    echo $f
    n=$f #${f#include/}
    a=`echo $f | sed -e s@include/@include/$UAPI/@`

    pn=`echo $n | sed -e s@/@__@g`

    ./disintegrate/disintegrate/uapi.pl $f $a || exit $?
    stg new uapi-$pn.diff -m "UAPI: Disintegrate $f

Signed-off-by: David Howells <dhowells@redhat.com>" || exit $?
    if [ -r $a ]
    then
	stg add $a || exit $?
    fi
    if [ ! -r $f ]
    then
	stg rm $f || exit $?
    fi
    stg ref || exit $?
done
