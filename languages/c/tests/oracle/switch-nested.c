int putchar(int c);
int main() {
    int i; int j; int n = 0;
    for (i = 0; i < 4; i++) {
        switch (i % 2) {
        case 0:
            for (j = 0; j < 3; j++) {
                switch (j) { case 1: continue; case 2: break; default: n += 100; }
                n++;
            }
            break;
        case 1:
            switch (i) { case 3: putchar('t'); break; } 
            putchar('o');
            continue;
        }
        putchar('e');
    }
    switch (n) { }
    switch (n) ;
    putchar(10);
    return n;
}
