int main(void) { long v = 0; switch (v) { case (sizeof(int) - 5) + (9223372036854775807 + 1): return 1; } return 0; }
