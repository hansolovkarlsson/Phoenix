struct p { int x; int y; };
typedef struct p P;
typedef int I;
P make(I x, I y) { P r; r.x = x; r.y = y; return r; }
I get(P q) { return q.x * 3 + q.y; }
int main() { return get(make(7, 5)); }
