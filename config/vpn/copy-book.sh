#! /bin/bash


if [[ "$1" != *"/shared/torrents/books"* ]];
then
  echo 'non-book torrent -- skipping'
  exit 0
fi

echo "Copying books from torrent: '$1'"

cd "$1"

find . -type f -regex '.*\.\(pdf\|mobi\|epub\|azw\|azw3\|djvu\|fb2\|lit\|pdb\)$' -exec cp {} /shared/upload \;