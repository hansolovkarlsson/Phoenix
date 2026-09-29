int main(void) { long v = 0; switch (v) { case 4L >> 63: return 1; } return 0; }
