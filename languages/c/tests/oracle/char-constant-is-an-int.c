/* A character constant is an `int` in C, C11 6.4.4.4, and a `char` only in
   C++. So its size is four. */
int main() { char c = 'a'; return sizeof 'a' * 10 + sizeof c; }
