#include <sys/ioctl.h>
#include <stdio.h>

int
main(void) {
  printf("0x%lx\n", TIOCGWINSZ);
  return 0;
}
