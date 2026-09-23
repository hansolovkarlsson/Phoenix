struct point { int x; int y; };
int main() { struct point p; p.x = 3; p.y = 4; p.x = p.x * p.y; return p.x + p.y; }
