int main(void) { long v = 0; switch (v) { case sizeof(int) / 0: return 1; } return 0; }
