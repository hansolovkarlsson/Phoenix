typedef char T;
int twice(int T);
int twice(int T) { return sizeof(T) * 100 + T * 2; }
int main() { T x = 21; return twice(x); }
