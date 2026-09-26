int printf(char *format, ...);
int answer = 42;
int table[4];
char *greeting = "hello";
int *where = &answer;
int *row = table;
int *nothing = 0;
struct pt { int x; int y; };
struct pt origin;
struct pt *here = &origin;
int main(void) {
    *where = 7; row[2] = 5; here->y = 9;
    printf("%s %d %d %d %d\n", greeting, answer, table[2], origin.y, nothing == 0);
    greeting = "bye"; where = &table[2];
    printf("%s %d\n", greeting, *where);
    return answer + table[2];
}
