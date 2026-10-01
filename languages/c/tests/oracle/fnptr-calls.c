int printf(const char *format, ...);
int add(int a, int b) { return a + b; }
int sub(int a, int b) { return a - b; }
int mul(int a, int b) { return a * b; }
int apply(int (*f)(int, int), int a, int b) { return f(a, b); }
int (*global_op)(int, int);
int main(void) {
    int (*op)(int, int) = add;
    int total = op(5, 3);
    op = sub;
    total = total * 10 + (*op)(5, 3);
    op = &mul;
    global_op = mul;
    int (*table[3])(int, int) = {add, sub, mul};
    int sum = 0;
    for (int i = 0; i < 3; i++) sum += table[i](7, 2);
    printf("%d %d %d %d\n", total, sum, apply(sub, 9, 4), global_op(6, 7));
    printf("%d %d %d\n", op == mul, op != add, op != 0);
    op = 0;
    return op == 0 ? apply(add, 1, 2) : 99;
}
