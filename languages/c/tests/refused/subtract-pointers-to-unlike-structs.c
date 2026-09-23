struct a { int x; };
struct b { int x; };
int main() { struct a p[2]; struct b q[2]; return &p[1] - &q[0]; }
