struct t { int a; int b; };
int main() { struct t a; struct t b; struct t c; c.a = 4; c.b = 5; a = b = c; c.a = 0; b.b = 7; return a.a * 10 + a.b + b.b * 100 + (a = b).b; }
