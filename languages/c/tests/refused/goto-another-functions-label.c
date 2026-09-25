int f() { here: return 1; }
int main() { goto here; return f(); }
