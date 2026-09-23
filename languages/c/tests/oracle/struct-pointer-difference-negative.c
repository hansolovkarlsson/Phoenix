struct t { int a; int b; int c; };
int main() { struct t a[3]; return (a - &a[2]) + 10; }
