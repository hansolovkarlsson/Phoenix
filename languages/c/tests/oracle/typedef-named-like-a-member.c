typedef int T;
struct s { T T; T *p; };
int main() { struct s v; v.T = 5; v.p = &v.T; *v.p = *v.p + 1; return v.T; }
