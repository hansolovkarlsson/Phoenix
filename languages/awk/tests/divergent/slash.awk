# `a/b/c` -- two divisions, written with no spaces.
#
# awk's lexer asks the parser whether a regexp may start here. Phoenix's is
# longest match over the token rules and has no such feedback, so `awk.phx`
# guesses from the character after the `/`: not a space, not a tab, not an `=`.
# That reads every regexp in the corpus and every division in it, and it reads
# this one wrong -- as `a` concatenated with the regexp `/b/` concatenated
# with `c`.
#
# It is here so that the guess has a witness. Rendering it back out puts the
# spaces in, which is what makes the divergence visible rather than silent.
BEGIN { print a/b/c }
