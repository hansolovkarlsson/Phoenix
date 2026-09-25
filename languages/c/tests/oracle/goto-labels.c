int putchar(int c);
int f_x(int n) { y: n++; if (n < 3) goto y; return n; }
int f(int n) { x_y: n = n + 10; if (n < 25) goto x_y; return n; }
int twice(int n) { int x = 0; x: x++; if (x < n) goto x; return x; }
int main() {
    int n = 0; int k = 0;
    goto inside;
    { int hidden = 5;
inside:
      n = n + 1;
      if (n < 4) goto inside;
    }
    a: b: k++;
    if (k < 2) goto a;
    if (k < 3) goto b;
    goto y;
    putchar('?');
y:  k = k + 0;
    goto end;
    putchar('!');
end: ;
    putchar('0' + k); putchar(10);
    return n * 10 + k + f_x(0) * 100 % 256 + f(0) + twice(3);
}
