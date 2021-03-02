#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h>
#include <errno.h>

int error(int err) {
	perror("Error");
	return 1;
}

int main() {
	sync();
#ifdef __linux__
	int fd = open("/proc/sys/vm/drop_caches", O_WRONLY);
	if (-1 == fd) {
		return error(errno);
	}
	if (-1 == write(fd, "3\n", 2)) {
		return error(errno);
	}
#endif
#ifdef __APPLE__
  // TODO
#endif
}
