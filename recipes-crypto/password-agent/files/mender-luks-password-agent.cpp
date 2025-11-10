#include <dirent.h>
#include <errno.h>
#include <iostream>
#include <limits.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

#include <signal.h>
#include <sys/socket.h>
#include <sys/un.h>

#include <INIReader.h>

#define ASK_PASSWD_DIR "/run/systemd/ask-password/"

int get_passwd(std::string &passwd) {
  const std::string cmd_str = "@@MENDER/LUKS_PASSWORD_AGENT_CMD@@";
  FILE *cmd = popen(cmd_str.c_str(), "r");
  if (cmd) {
    char key_str[2048];
    const auto fgets_rtn = fgets(key_str, sizeof(key_str), cmd);

    if ((pclose(cmd) == 0) && (fgets_rtn != NULL)) {
      passwd = std::string(key_str);
      while (!passwd.empty() && passwd.back() == '\n') {
        passwd.pop_back();
      }
      return 0;
    }
  }
  return -1;
}

int write_passwd(std::string socket, std::string passwd) {
  const std::string cmd_str = "/lib/systemd/systemd-reply-password 1 " + socket;
  FILE *cmd = popen(cmd_str.c_str(), "w");
  if (cmd) {
    const auto fputs_rtn = fputs(passwd.c_str(), cmd);
    return ((pclose(cmd) == 0) && (fputs_rtn != EOF)) ? 0 : -1;
  }
  return -1;
}

int main(int argc, char **argv) {
  DIR *dir = opendir(ASK_PASSWD_DIR);
  if (dir) {
    struct dirent *de;
    while ((de = readdir(dir)) != NULL) {
      if (de->d_type != DT_REG)                continue;
      if (strncmp(de->d_name, "ask.", 4) != 0) continue;

      const INIReader reader(std::string(ASK_PASSWD_DIR) + std::string(de->d_name));
      if (!reader.ParseError()) {
        const std::string id = reader.Get("Ask", "Id", "");
        if (id.empty()) {
          fprintf(stderr, "error parsing [Ask]Id: %s\n", strerror(errno));
          continue;
        }
        if (id.compare(0, 10, "cryptsetup") != 0) {
          fprintf(stderr, "Id (%s) != cryptsetup*, skipping this Id\n", id.c_str());
          continue;
        }

        const int pid = reader.GetInteger("Ask", "PID", -1);
        if (pid == -1) {
          fprintf(stderr, "error parsing [Ask]PID: %s\n", strerror(errno));
          continue;
        }
        if (kill(pid, 0) != 0) {
          if (errno == ESRCH) {
            fprintf(stderr, "error on kill(%d,0): %s\n", pid, strerror(errno));
            continue;
          }
        }

        const std::string socket = reader.Get("Ask", "Socket", "");
        if (socket.empty()) {
          fprintf(stderr, "error parsing [Ask]Socket: %s\n", strerror(errno));
          continue;
        }

        std::string passwd;
        if (get_passwd(passwd) == 0) {
          if (write_passwd(socket, passwd) == 0) {
            ; // success
          }
        }
      } // if(INIReader)
    }   // while
  }     // if(dir)
  closedir(dir);
  exit(0);
}
