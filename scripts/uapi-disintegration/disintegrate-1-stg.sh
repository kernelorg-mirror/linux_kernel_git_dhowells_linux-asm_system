#!/bin/sh

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

stg new uapi-all-headers.diff -m "UAPI: Disintegrate $f

Signed-off-by: David Howells <dhowells@redhat.com>" || exit $?

{
    ./disintegrate/uapi/genlist.pl
    #./disintegrate/uapi/genlist.pl | grep include/linux/ 
    #echo include/linux/patchkey.h
    #echo include/linux/sched.h
} |
while read f
do
    if [ ! -f $f ]
    then
	continue
    fi

    echo $f
    n=$f #${f#include/}
    a=`echo $f | sed -e s@include/include/@$UAPI/@`

    pn=`echo $n | sed -e s@/@__@g`

    ./disintegrate/disintegrate/uapi.pl $f $a || exit $?
    if [ -r $a ]
    then
	stg add $a || exit $?
    fi
    if [ ! -r $f ]
    then
	stg rm $f || exit $?
    fi
done

stg ref || exit $?
