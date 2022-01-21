#include <sys/ioctl.h>
#include <stdio.h>

int
main(void) {
  printf("0x%lx\n", (unsigned long)TIOCGWINSZ);
  return 0;
}
