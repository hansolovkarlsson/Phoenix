# Phoenix -- a compiler-compiler.
#
#   make           build bin/phx
#   make test      build and run the tests
#   make clean

CC      ?= cc
CFLAGS  ?= -std=c11 -O2 -g
WARN     = -Wall -Wextra -Wpedantic -Wshadow -Wstrict-prototypes \
           -Wmissing-prototypes -Wno-unused-parameter

SRC = phoenix/support.c phoenix/grammar.c phoenix/check.c phoenix/expr.c \
      phoenix/eval.c phoenix/library.c phoenix/pass.c phoenix/run.c \
      phoenix/lex.c phoenix/parse.c phoenix/main.c
HDR = phoenix/phx.h

all: bin/phx

bin/phx: $(SRC) $(HDR)
	@mkdir -p bin
	$(CC) $(CFLAGS) $(WARN) -o $@ $(SRC)

test: bin/phx
	@tests/run.sh

clean:
	rm -rf bin

.PHONY: all test clean
