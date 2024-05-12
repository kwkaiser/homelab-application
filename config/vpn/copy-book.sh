#! /bin/bash

FILES=$(find "$1" -type f -regex '.*\.\(pdf\|mobi\|epub\|azw\|azw3\|djvu\|fb2\|lit\|pdb\)$' | grep -i '/shared/torrents/books')
cp "$FILES" /shared/upload/