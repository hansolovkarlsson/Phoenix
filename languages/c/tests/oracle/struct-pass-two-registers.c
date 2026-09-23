struct p3 { int x; int y; int z; };
struct p4 { int w; int x; int y; int z; };
int f(int k, struct p3 a, struct p4 b, int m) { return k + a.x + a.y * 2 + a.z * 3 + b.w * 4 + b.x * 5 + b.y * 6 + b.z * 7 + m * 8; }
int main() { struct p3 a; struct p4 b; a.x = 1; a.y = 2; a.z = 3; b.w = 4; b.x = 5; b.y = 6; b.z = 7; return f(1, a, b, 2); }
