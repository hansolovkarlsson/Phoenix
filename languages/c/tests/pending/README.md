# pending

Witnesses for an open entry that Phoenix does not compile yet, kept here
because `../oracle/run.sh` runs every program in its own directory and these
would fail it. Nothing runs this directory. Each program moves to `../oracle/`
with the part of its entry that makes it agree with `cc`, and the directory
is empty when the entry closes. It is empty now: no entry is open.
[6.12](../../../../docs/COMPLETED.md#612-declarations-as-c11-67-has-them)
was the first to use it, and
[6.13](../../../../docs/COMPLETED.md#613-initialisers-as-c11-679-has-them)
the second.
