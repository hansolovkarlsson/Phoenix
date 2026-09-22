int main() { char s[3]; char *p = s; *(p + 2) = 7; p[1] = 5; return s[2] * 10 + *(s + 1) + (&s[2] - p) * 100; }
