struct s { int x; }; int main(void) { struct s a; const struct s *p = &a; p->x = 1; return 0; }
