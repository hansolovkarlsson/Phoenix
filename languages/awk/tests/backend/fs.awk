# A field separator of more than one character is a regular expression, which
# is what mve.awk's FS = "[:,]" means.
BEGIN { FS = "[:,]" }
{ print NF, $1, $2, $NF }
