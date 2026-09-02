# `f (1)` -- a space between the name and the parenthesis.
#
# In awk that is **not a call**: it is the variable `f` concatenated with a
# parenthesised expression, and POSIX says so by making `FUNC_NAME` a name
# *immediately* followed by `(`. Saying that in Phoenix means putting the `(`
# inside the token, and then `if(`, `while(` and `print(` become function
# names too -- so this description does not say it, and reads a call.
#
# The corpus defines no functions, so nothing there depends on it. One program
# outside the subset does: `outside/hello.awk` calls a gawk builtin that way.
BEGIN { x = f (1) }
