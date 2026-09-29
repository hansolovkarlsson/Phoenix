int main(void) { long v = 0; switch (v) { case 4L >> 64: return 1; } return 0; }
