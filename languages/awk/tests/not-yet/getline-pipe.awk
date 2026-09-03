# `cmd | getline` -- read now, and still not compiled.
#
# It was in `divergent/` while `|` was not an expression operator and this did
# not parse. It parses now, so it belongs here with the other `getline`: the
# backend refuses every form of it by name, and this is the form that took a
# rung of the ladder to describe.
BEGIN { "date" | getline stamp; print stamp }
