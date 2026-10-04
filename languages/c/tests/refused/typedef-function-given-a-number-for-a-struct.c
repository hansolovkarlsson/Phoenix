struct s { int a; }; typedef int taker(struct s v); taker take; int main(void) { return take(1); }
