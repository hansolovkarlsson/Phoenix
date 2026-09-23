typedef char T;
int main() { int r; { int T = 3; r = sizeof(T) * 10 + T; } return r * 10 + sizeof(T); }
