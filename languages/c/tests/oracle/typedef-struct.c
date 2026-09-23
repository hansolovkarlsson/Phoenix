struct point { int x; int y; };
typedef struct point point;
typedef struct point *where;
int main() { point p; where w = &p; w->x = 30; p.y = 12; return p.x + w->y + sizeof(point) * 10; }
