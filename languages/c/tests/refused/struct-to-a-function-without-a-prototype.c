struct s { int a; }; int take(); int main(void) { struct s v = {1}; return take(v); }
