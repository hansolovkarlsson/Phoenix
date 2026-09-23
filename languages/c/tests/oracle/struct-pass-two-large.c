struct big { int v[5]; };
int diff(struct big a, int k, struct big b) { return (a.v[0] - b.v[0]) * 10 + a.v[4] - b.v[4] + k; }
int main() { struct big a; struct big b; int i; for (i = 0; i < 5; i = i + 1) { a.v[i] = 9; b.v[i] = i; } return diff(a, 100, b) + diff(b, diff(a, 0, b), a); }
