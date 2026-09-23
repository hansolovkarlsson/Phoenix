struct pt { int x; int y; };
typedef struct pt point;
int sum(point p) { return p.x + p.y; }
int main() { point a; point b; a.x = 20; a.y = 22; b = a; point c = b; return sum(c); }
