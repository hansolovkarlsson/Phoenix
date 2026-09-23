struct pt { int x; int y; };
struct box { struct pt lo; struct pt hi; char tag[4]; };
int main() {
    struct box b; struct box c; struct pt ps[3]; struct pt *q;
    b.lo.x = 1; b.lo.y = 2; b.hi.x = 3; b.hi.y = 4; b.tag[0] = 5; b.tag[3] = 6;
    c = b; c.hi = c.lo; ps[2] = b.hi; ps[0] = ps[2]; q = &ps[1]; *q = ps[0]; q->x = 9;
    return c.hi.x + c.hi.y * 10 + c.tag[3] * 100 + ps[0].x + ps[1].x * 2 + ps[2].y * 3;
}
