# awk finds this when the call runs -- `calling undefined function f` -- which
# is to say: on the input that reaches it, on somebody else's machine. The
# check in awk.phx finds it while reading the program.
BEGIN { print f(1) }
