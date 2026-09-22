int main() { char c = 3; char *p = &c; char **pp = &p; **pp = 4; return **pp * 10 + c; }
