struct p { int a; int b; };
struct box { char tag; int dims[3]; struct p q; };
struct box elided = {1, 7, 8, 9, 10, 11};
int main(void) { return elided.q.b; }
