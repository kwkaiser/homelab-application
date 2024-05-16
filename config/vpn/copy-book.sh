#! /bin/bash

echo "Copying books from torrent: '$1'"

FILES=$(find "$1" -type f -regex '.*\.\(pdf\|mobi\|epub\|azw\|azw3\|djvu\|fb2\|lit\|pdb\)$' | grep -i '/shared/torrents/books' | xargs)
cp $FILES /shared/upload/