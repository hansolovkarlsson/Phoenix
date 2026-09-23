struct point { int x; int y; };
int main() { struct point p; struct point *q; q = &p; q->x = 7; (*q).y = 5; return p.x * 10 + q->y; }
