struct s { int v[2]; }; int main(void) { struct s a; const struct s *p = &a; p->v[1] = 1; return 0; }
