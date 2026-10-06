/* A function declared in a block is in force to the block's end, C11
 * 6.2.1p4: it hides a local of its name there, by a declarator and by a
 * typedef of its type, and the local is back after it; a local in a
 * block inside hides it in turn; declared again at file scope, by a
 * prototype, a typedef or a definition, it is known from there on, in
 * every function after; and one declared at file scope first is still
 * known after a block declares it again. */
int printf(const char *, ...);
typedef int binop(int, int);
int last(void);
int early(void) {
    int twice(int), thrice(int);
    binop sub;
    return twice(4) + thrice(1) + sub(9, 1);
}
int twice(int);
binop sub;
int later(void) { return twice(5) + sub(3, 2); }
int thrice(int n) { return 3 * n; }
int last(void) { return thrice(2); }
int main(void) {
    int twice = 3, add = 100;
    {
        int twice(int), later(void);
        binop add, sub;
        int (*p)(int) = twice;
        printf("%d %d %d\n", twice(6), add(1, 2), p(7) == twice(7));
        {
            int twice = 9;
            printf("%d\n", twice);
        }
        printf("%d %d\n", twice(1), &twice == p);
    }
    printf("%d %d %d %d %d %d\n", twice, add, early(), later(), last(), sub(5, 4));
    return twice + add;
}
int twice(int n) { return 2 * n; }
int add(int a, int b) { return a + b; }
int sub(int a, int b) { return a - b; }
