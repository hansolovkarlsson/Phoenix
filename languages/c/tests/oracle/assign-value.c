/* Assignment is an expression worth what was assigned, and it groups to
   the right: both get 21. */
int main() { int a; int b; a = b = 21; return a + b; }
