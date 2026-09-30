struct p { int a; }; struct q { int a; }; struct w { struct p m; }; int main(void) { struct q v; v.a = 1; struct w x = {v}; return x.m.a; }
