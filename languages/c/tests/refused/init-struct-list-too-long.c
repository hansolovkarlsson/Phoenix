struct p { int a; int b; }; struct p two[2] = {{1, 2}, {3, 4}, {5, 6}}; int main(void) { return two[0].a; }
