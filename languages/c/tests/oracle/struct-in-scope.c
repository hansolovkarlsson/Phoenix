struct box { int v; };
int main() { struct box b; b.v = 1; { struct box b; b.v = 20; { struct box *p; p = &b; p->v = p->v + 1; } b.v = b.v + 1; } return b.v; }
