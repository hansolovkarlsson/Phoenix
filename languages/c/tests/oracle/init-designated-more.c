int printf(char *format, ...);
struct pair { int a; int b; };
struct rec { int a; int b; int c[2]; char name[4]; };
struct deep3 { struct { int v[2]; } in[2]; int z; };
int g = 7, h = 8;
int twice[3] = {[1] = 1, [1] = 2};
int sized[] = {[5] = 1};
int back2[] = {[4] = 1, [1] = 2};
struct mid { char pad[20000]; int x; } m = {.x = 5};
int *ptrs[2] = {[1] = &g, [0] = &h};
struct deep3 d3 = {1, 2, 3, 4, 5};
struct rec onward = {.b = 1, 2, 3, .name = "abc"};
struct pair make(int x) { struct pair p; p.a = x; p.b = x * 2; return p; }
int kept(void) { static int back[4] = {[3] = 3, [1] = 1}; back[0] += 1; return back[0] + back[1] + back[3]; }
int main(void) {
    int l[3] = {[2] = 3, [0] = 1, [2] = 9};
    struct pair arr[2] = {[1] = make(5)};
    struct deep3 ld = {1, 2, 3};
    kept();
    printf("%d %d %lu %d %d %d\n", twice[1], twice[2], sizeof sized, sized[5], *ptrs[0], *ptrs[1]);
    printf("%d %d %d %d %d %d %d %d %s\n", d3.in[0].v[1], d3.in[1].v[0], d3.in[1].v[1], d3.z, onward.a, onward.b, onward.c[0], onward.c[1], onward.name);
    printf("%d %d %d %d %d %d %d %d\n", kept(), l[0], l[1], l[2], arr[1].a, arr[1].b, ld.in[1].v[0], ld.z);
    printf("%lu %d %d %d\n", sizeof back2, back2[4], back2[1], m.x);
    return l[2];
}
