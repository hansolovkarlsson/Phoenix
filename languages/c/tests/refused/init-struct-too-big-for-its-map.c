struct big { char b[40000]; int x; };
struct big g = {.x = 1};
int main(void) { return g.x; }
