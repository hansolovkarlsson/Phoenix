struct t { int v[3]; };
int copy(struct t *to, struct t *from) { *to = *from; return 0; }
int main() { struct t a; struct t b; a.v[0] = 7; a.v[1] = 8; a.v[2] = 9; copy(&b, &a); a.v[1] = 0; return b.v[0] + b.v[1] * 2 + b.v[2] * 3; }
