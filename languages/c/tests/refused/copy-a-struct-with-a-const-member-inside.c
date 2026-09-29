struct in { const int x; }; struct out { int y; struct in i; }; int main(void) { struct out a; struct out b; a = b; return 0; }
