struct s { int a; }; int main() { struct s v; v.a = 1; v = (struct s)v; return v.a; }
