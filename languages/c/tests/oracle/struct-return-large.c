struct big { int v[6]; char t; };
int twice(int n) { return n * 2; }
struct big make(int k) {
    struct big b; int i;
    for (i = 0; i < 6; i = i + 1) b.v[i] = k + i;
    b.t = twice(k);
    return b;
}
int main() { struct big b = make(3); int s = 0; int i; for (i = 0; i < 6; i = i + 1) s = s + b.v[i]; return s + b.t; }
