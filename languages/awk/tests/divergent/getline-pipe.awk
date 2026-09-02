# `cmd | getline` -- the two forms of getline this grammar does not describe,
# because `|` would have to be an expression operator and it is otherwise only
# a print redirect. Not described means not parsed, which is loud.
BEGIN { "date" | getline stamp; print stamp }
