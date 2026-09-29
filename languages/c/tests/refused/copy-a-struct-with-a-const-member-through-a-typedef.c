struct in { const int x; }; typedef struct in tin; struct out { tin i; }; int main(void) { struct out a; struct out b; a = b; return 0; }
