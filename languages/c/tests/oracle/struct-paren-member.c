struct pair { int a; int b; };
int main() { struct pair s; struct pair *p; p = &s; (s).a = 3; (*p).b = 4; (p)->a = (&s)->a * 2; return s.a * 10 + (s).b; }
