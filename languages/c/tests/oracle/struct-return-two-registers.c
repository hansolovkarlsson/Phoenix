struct p3 { int x; int y; int z; };
struct p4 { int w; int x; int y; int z; };
struct p3 three(int k) { struct p3 p; p.x = k; p.y = k * 2; p.z = k * 3; return p; }
struct p4 four(int k) { struct p4 p; p.w = k; p.x = k + 1; p.y = k + 2; p.z = k + 3; return p; }
int main() { struct p3 a = three(2); struct p4 b = four(10); return a.x + a.y * 2 + a.z * 3 + b.w + b.x * 2 + b.y * 3 + b.z * 4; }
