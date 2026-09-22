/* A plain `char` is signed on Apple's arm64, which is where Apple departs from
   AAPCS64, whose `char` is unsigned. 200 does not fit, and comes back as -56. */
int main() { char c = 200; return (c < 0) * 100 + (c == 0 - 56); }
