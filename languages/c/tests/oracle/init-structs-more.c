int printf(char *format, ...);
struct pair { int a; int b; };
struct label { char name[8]; int n; };
struct holder { struct pair ps[2]; char tag; };
struct one { char c; };
struct padded { char c; long l; char d; };
struct label glabel = {"global", 9};
struct holder gholder = {{{1, 2}, {3, 4}}, 'h'};
struct one gone = {'x'};
struct padded gpad = {'p', 77, 'q'};
struct outer { struct inner { int k; } in; int z; } gouter = {{5}, 6};
typedef struct later2 L2;
struct later2 { int a; long b; };
L2 gl2 = {1, 2};
int main(void) {
    struct label l = {"hi", 3};
    struct holder h = {{{5, 6}}, 'k'};
    struct pair list[] = {{1, 1}, {2, 4}, {3, 9}};
    struct one lone = {'y'};
    struct padded lpad = {'r', -5, 's'};
    printf("%s %d %s %d %d %d %c\n", glabel.name, glabel.n, l.name, l.n, l.name[7], gholder.ps[1].a, gholder.tag);
    printf("%d %d %d %c %lu %d %c %c\n", h.ps[0].b, h.ps[1].a, h.ps[1].b, h.tag, sizeof list, list[2].b, gone.c, lone.c);
    printf("%c %ld %c %c %ld %c %lu\n", gpad.c, gpad.l, gpad.d, lpad.c, lpad.l, lpad.d, sizeof gpad);
    struct inner lin = {8};
    L2 ll2 = {3, 4};
    printf("%d %d %d %ld %lu %ld %lu\n", gouter.in.k, gouter.z, lin.k, gl2.b, sizeof gl2, ll2.b, sizeof ll2);
    return list[1].b + l.n;
}
