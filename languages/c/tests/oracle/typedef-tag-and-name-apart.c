struct T { char c; int i; };
typedef int T;
int main() { struct T s; T t = 3; s.c = 2; s.i = t; return sizeof(struct T) * 10 + sizeof(T) + s.c + s.i; }
