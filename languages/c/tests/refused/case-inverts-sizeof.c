int main(void) { long v = -5; switch (v) { case ~sizeof(int): return 1; } return 0; }
