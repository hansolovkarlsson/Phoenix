struct p { int x; int y; };
struct big { int v[6]; };
struct p deref(struct p *q) { return *q; }
struct big copy(struct big *b) { return *b; }
struct p member(struct big *b) { struct p r; r.x = b->v[1]; r.y = b->v[2]; return r; }
int main() {
    struct p a; struct big b; struct big c; int i;
    a.x = 4; a.y = 9;
    for (i = 0; i < 6; i = i + 1) b.v[i] = i * 3;
    c = copy(&b); b.v[5] = 100;
    return deref(&a).x + deref(&a).y * 2 + c.v[5] + member(&c).y;
}
