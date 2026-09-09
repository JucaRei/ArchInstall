#!/usr/bin/env bash

whom_variable="World"

printf "Hello, %s\n" "$whom_variable"

weak="weak quoting"
echo "Hello, i'm using $weak."
# echo "Hello, i'm using \$weak."

strong="strong quoting"
echo 'Hello, im using $strong.'

