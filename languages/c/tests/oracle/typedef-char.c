typedef char byte;
typedef char *string;
int puts(string s);
int main() { byte b[4]; string s = "typed"; b[0] = 'o'; b[1] = 'k'; b[2] = 0; puts(s); puts(b); return sizeof(byte) + sizeof(b) * 10 + sizeof(string) * 100; }
